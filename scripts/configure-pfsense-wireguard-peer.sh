#!/bin/bash

# Attendre que pfSense soit prêt et que le service WireGuard soit démarré
echo "Waiting for pfSense WireGuard service to be ready..."
sleep 10 # Attendre un peu plus pour s'assurer que tout est stable

# Attendre que le fichier siteb_wg_public_key.txt soit disponible sur le dossier partagé /vagrant
echo "Waiting for siteb_wg_public_key.txt to be available in /vagrant..."
while [ ! -f "/vagrant/siteb_wg_public_key.txt" ]; do
    echo "Still waiting for siteb_wg_public_key.txt..."
    sleep 5
done
echo "siteb_wg_public_key.txt found. Reading Site B public key."
SITEB_PUBLIC_KEY=$(cat /vagrant/siteb_wg_public_key.txt | tr -d '\n' | tr -d '\r')

if [ -z "$SITEB_PUBLIC_KEY" ]; then
    echo "Error: Site B public key is empty after reading. VPN configuration on pfSense will be incomplete."
    exit 1
fi

# Récupérer la clé privée et publique de pfSense (générées plus tôt par provision-pfsense.sh)
PFSENSE_PRIV_KEY_PATH="/usr/local/etc/wireguard/privkey"
PFSENSE_PUB_KEY_PATH="/usr/local/etc/wireguard/pubkey"

expect -c "
    spawn ssh admin@192.168.1.1 \"
        # S'assurer que les clés pfSense existent avant de les utiliser
        if [ ! -f ${PFSENSE_PRIV_KEY_PATH} ]; then
            echo \\\"Generating pfSense WireGuard keys...\\\"
            wg genkey | sudo tee ${PFSENSE_PRIV_KEY_PATH} > /dev/null
            sudo chmod 600 ${PFSENSE_PRIV_KEY_PATH}
            sudo cat ${PFSENSE_PRIV_KEY_PATH} | wg pubkey | sudo tee ${PFSENSE_PUB_KEY_PATH} > /dev/null
        fi
        sudo sysrc wireguard_enable=YES # S'assurer que WireGuard est activé au boot
        
        echo \\\"Creating peer for Site B with public key ${SITEB_PUBLIC_KEY}\\\"

        PFSENSE_PRIV_KEY=\$(sudo cat ${PFSENSE_PRIV_KEY_PATH})
        # Configuration du peer WireGuard. L'IP de Site B est 192.168.2.10 sur OPT1, et son port WireGuard est 51820
        # Les AllowedIPs doivent inclure les réseaux que pfSense doit router vers Site B via le tunnel,
        # et le point d'entrée du tunnel WireGuard de Site B (10.6.210.0/31).
        # Attention: 10.6.210.0/31 signifie 10.6.210.0 et 10.6.210.1.
        # Si Site B a 10.6.210.0/31, alors son IP WireGuard est 10.6.210.0 et pfSense est 10.6.210.1.
        # Les AllowedIPs pour le peer sur pfSense devraient inclure 10.6.210.0/32 et le réseau LAN de Site B (192.168.2.0/24)
        sudo wg set wg0 private-key ${PFSENSE_PRIV_KEY} peer ${SITEB_PUBLIC_KEY} endpoint 192.168.2.10:51820 allowed-ips 192.168.2.0/24,10.6.210.0/32 persistent-keepalive 25
        
        echo \\\"Bringing up WireGuard interface and restarting service...\\\"
        sudo wg-quick up wg0 # Tenter de monter l'interface
        sudo /usr/local/sbin/pfSsh.php playback enableinterface wg0 # S'assurer que l'interface est activée dans pfSense
        sudo /usr/local/sbin/pfSsh.php playback servicerepeat wg restart # Redémarrer le service WireGuard

        echo \\\"WireGuard peer for Site B added on pfSense.\\\"
    \"
    expect \"Password:\"
    send \"vagrant\r\"
    expect eof
"
echo "WireGuard peer configuration for Site B completed on pfSense."