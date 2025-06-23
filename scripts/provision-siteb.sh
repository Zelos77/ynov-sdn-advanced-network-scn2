#!/bin/bash

echo "Provisioning Site B..."

# Configuration Netplan pour Site B (CORRIGÉE avec sudo tee)
sudo rm -f /etc/netplan/*.yaml
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8: # Assurez-vous que c'est la bonne interface pour 192.168.2.10
      dhcp4: no
      addresses: [192.168.2.10/24]
      routes:
        - to: default
          via: 192.168.2.1
      nameservers:
        addresses: [192.168.2.1, 8.8.8.8]
    enp0s9: # Assurez-vous que c'est la bonne interface pour 10.0.0.1
      dhcp4: no
      addresses: [10.0.0.1/24]
EOF
sudo netplan apply

# Activation du forwarding IP sur Site B (routeur)
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Installation de FRRouting
echo "Installing FRRouting on Site B..."
sudo apt update
sudo apt install -y apt-transport-https gnupg
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
echo "deb https://deb.frrouting.org/frr $(lsb_release -sc) frr-stable" | sudo tee /etc/apt/sources.list.d/frr.list
sudo apt update
sudo apt install -y frr frr-pythontools

# Activer les démons FRR
sudo sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons # Si vous comptez utiliser BGP plus tard
sudo systemctl enable frr
sudo systemctl start frr
echo "FRRouting installed and started on Site B."

# Configuration de FRRouting pour OSPF
# Note: Ce script de configuration simple doit être étendu pour des cas d'usage réels.
sudo tee /etc/frr/frr.conf > /dev/null <<EOF
hostname site_b_router
password frr
enable password frr

log file /var/log/frr/frr.log

router ospf
  ospf router-id 10.0.0.1
  network 192.168.2.0/24 area 0
  network 10.0.0.0/24 area 0
  !
  # Redistribuer les routes connectées ou statiques si nécessaire
  # redistribute connected
  # redistribute static
  !
line vty
EOF
sudo chown frr:frr /etc/frr/frr.conf
sudo chmod 640 /etc/frr/frr.conf
sudo systemctl restart frr
echo "FRRouting configured for OSPF on Site B."

# Installation de WireGuard
echo "Installing WireGuard on Site B..."
sudo apt update
sudo apt install -y wireguard

# Configuration de WireGuard (wg0.conf)
# Utilise la clé publique de pfSense passée en variable d'environnement
PFSENSE_PUBLIC_KEY="$PFSENSE_WG_PUBLIC_KEY"

if [ -z "$PFSENSE_PUBLIC_KEY" ]; then
    echo "Error: pfSense public key not found. WireGuard configuration will be incomplete."
    exit 1
fi

sudo mkdir -p /etc/wireguard
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 10.6.210.0/31 # Votre IP WireGuard dans le tunnel, /31 pour un lien point à point
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o enp0s8 -j MASQUERADE

[Peer]
PublicKey = ${PFSENSE_PUBLIC_KEY}
Endpoint = 192.168.2.1:51820 # L'IP OPT1 de pfSense et le port WireGuard
AllowedIPs = 192.168.1.0/24, 192.168.3.0/24, 10.6.210.1/32 # Le réseau LAN de Site A, Monitoring et l'IP WireGuard de pfSense
PersistentKeepalive = 25
EOF

sudo chmod 600 /etc/wireguard/wg0.conf
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0.service
echo "WireGuard configured and started on Site B."

# Enregistrer la clé publique de Site B sur l'hôte pour pfSense
# Le dossier /vagrant est le dossier partagé avec l'hôte
wg pubkey > /vagrant/siteb_wg_public_key.txt
echo "Site B WireGuard public key extracted to siteb_wg_public_key.txt"


# Installation de Node Exporter
echo "Installing Node Exporter on Site B..."
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
echo "Node Exporter installed and started on Site B."