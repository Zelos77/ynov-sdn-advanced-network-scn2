#!/bin/bash

echo "Provisioning Site A..."

# Configuration Netplan pour Site A (CORRIGÉ)
sudo rm -f /etc/netplan/*.yaml
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8: # Assurez-vous que c'est la bonne interface pour 192.168.1.10
      dhcp4: no
      addresses: [192.168.1.10/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]
EOF
sudo netplan apply

# Activation du forwarding IP (si Site A doit router, bien que ce ne soit pas son rôle principal ici)
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Installation de Node Exporter
echo "Installing Node Exporter on Site A..."
sudo useradd -rs /bin/false node_exporter
NODE_EXPORTER_VERSION="1.8.2" # Vérifiez la dernière version sur GitHub
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
tar xvf /tmp/node_exporter.tar.gz -C /tmp/
sudo mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo rm /tmp/node_exporter.tar.gz
sudo rm -rf /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

# Création du service systemd pour Node Exporter
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
echo "Node Exporter installed and started on Site A."