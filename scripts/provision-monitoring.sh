#!/bin/bash

echo "Provisioning Monitoring Server..."

# Configuration Netplan pour Monitoring (CORRIGÉ)
sudo rm -f /etc/netplan/*.yaml
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8: # Assurez-vous que c'est la bonne interface pour 192.168.3.10
      dhcp4: no
      addresses: [192.168.3.10/24]
      routes:
        - to: default
          via: 192.168.3.1
      nameservers:
        addresses: [192.168.3.1, 8.8.8.8]
EOF
sudo netplan apply

# Installation de Prometheus
echo "Installing Prometheus..."
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

PROMETHEUS_VERSION="2.55.0" # Vérifiez la dernière version stable sur GitHub
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
tar xvf /tmp/prometheus.tar.gz -C /tmp/
sudo mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus
sudo mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus
sudo mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/prometheus.yml # Garder le fichier de configuration par défaut pour l'instant

sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Modifier prometheus.yml pour ajouter les cibles Node Exporter
# Supposons que les IPs sont fixes comme dans votre Vagrantfile
sudo tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOF
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100', '192.168.1.10:9100', '192.168.2.10:9100']
EOF

# Création du service systemd pour Prometheus
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network-online.target


User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
echo "Prometheus installed and started."

# Installation de Grafana
echo "Installing Grafana..."
sudo apt install -y gnupg2 apt-transport-https software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/grafana.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/grafana.gpg] https://packages.grafana.com/oss/deb stable main' | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana

sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
echo "Grafana installed and started."

# Note: L'ajout de Prometheus comme source de données dans Grafana et l'importation de tableaux de bord
# doivent être effectués manuellement via l'interface web de Grafana (http://192.168.3.10:3000, admin/admin)