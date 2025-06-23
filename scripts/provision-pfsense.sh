#!/bin/bash

# Attendre que pfSense soit prêt (le service SSH démarre après l'import XML)
echo "Waiting for pfSense SSH to be available..."
until nc -z -w 5 192.168.1.1 22; do
    sleep 5
done
echo "pfSense SSH is up. Proceeding with package installation."

# Installer les paquets FRR et WireGuard via SSH
# Utilise expect pour automatiser la saisie du mot de passe 'vagrant'
echo "Installing FRR and WireGuard packages on pfSense..."
expect -c '
    spawn ssh admin@192.168.1.1 pkg install -y frr wireguard
    expect "Password:"
    send "vagrant\r"
    expect eof
'
echo "FRR and WireGuard packages installation initiated on pfSense."

# Important: La clé WireGuard de pfSense sera générée et le peer configuré par 'configure-pfsense-wireguard-peer.sh'
# ce script ne fera plus la génération de clé initiale.