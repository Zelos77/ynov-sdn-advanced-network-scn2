Vagrant.configure("2") do |config|
  # pfSense VM
  config.vm.define "pfsense" do |pfsense|
    pfsense.vm.box = "ksklareski/pfsense-ce"
    pfsense.ssh.shell = "/bin/sh"      # Keep this from the previous fix
    pfsense.ssh.password = "vagrant"   # <--- ADD THIS LINE: Use password 'vagrant' for the 'vagrant' user
    pfsense.ssh.insert_key = false     # <--- ADD THIS LINE: Prevent Vagrant from inserting its own key

    pfsense.vm.network :private_network, ip: "192.168.1.1", virtualbox__intnet: "lan_site_a" # LAN for Site A
    pfsense.vm.network :private_network, ip: "192.168.2.1", virtualbox__intnet: "lan_site_b" # OPT1 for Site B
    pfsense.vm.network :private_network, ip: "192.168.3.1", virtualbox__intnet: "lan_monitoring" # OPT2 for Monitoring
    pfsense.vm.network "public_network", type: "dhcp" # WAN (NAT/Bridged)
    pfsense.vm.provider "virtualbox" do |vb|
      vb.name = "pfSense-NVA"
      vb.memory = "2048"
      vb.cpus = 2
    end
    # Provisionnement de pfSense avec le fichier de configuration XML et redémarrage
    pfsense.vm.provision "file", source: "pfsense-initial-config.xml", destination: "/tmp/config.xml"
    pfsense.vm.provision "shell", inline: <<-SHELL, reboot: true
      # Copier le fichier de configuration et redémarrer pfSense pour appliquer
      cp /tmp/config.xml /conf/config.xml
      rm /tmp/config.cache
      echo "Applying pfSense config and initiating reboot..."
      /sbin/reboot # Utiliser /sbin/reboot pour s'assurer que c'est une commande connue
    SHELL
    # Installer les paquets FRR et WireGuard, et générer la clé de pfSense
    pfsense.vm.provision "shell", path: "./scripts/provision-pfsense.sh"

    # Dernière étape de provisionnement pour configurer le peer WireGuard sur pfSense
    # Le script configure-pfsense-wireguard-peer.sh gérera l'attente du fichier siteb_wg_public_key.txt
    pfsense.vm.provision "shell", run: "always", path: "./scripts/configure-pfsense-wireguard-peer.sh"
  end

  # Site A VM
  config.vm.define "site_a" do |site_a|
    site_a.vm.box = "ubuntu/jammy64"
    site_a.vm.network :private_network, ip: "192.168.1.10", virtualbox__intnet: "lan_site_a" # Connects to pfSense LAN
    site_a.vm.provider "virtualbox" do |vb|
      vb.name = "Site-A-Client"
      vb.memory = "1024"
      vb.cpus = 1
    end
    site_a.vm.provision "shell", path: "./scripts/provision-sitea.sh"
  end

  # Site B VM
  config.vm.define "site_b" do |site_b|
    site_b.vm.box = "ubuntu/jammy64"
    site_b.vm.network :private_network, ip: "192.168.2.10", virtualbox__intnet: "lan_site_b" # Connects to pfSense OPT1
    site_b.vm.network :private_network, ip: "10.0.0.1", virtualbox__intnet: "vpn_tunnel_conceptual" # Conceptual for VPN tunnel
    site_b.vm.provider "virtualbox" do |vb|
      vb.name = "Site-B-Router"
      vb.memory = "1024"
      vb.cpus = 1
    end

    # Attendre que la clé publique de pfSense soit générée par son provisionnement
    site_b.vm.provision "shell", type: "pre_setup", run: "always", inline: <<-SHELL
      while [ ! -f "./pfsense_wg_public_key.txt" ]; do
        echo "Waiting for pfsense_wg_public_key.txt to be created by pfSense provisioning..."
        sleep 5
      done
      echo "pfSense public key file found."
    SHELL

    # Lire la clé publique de pfSense sur l'hôte et la passer à Site B
    pfsense_public_key = ""
    if File.exist?("pfsense_wg_public_key.txt")
      pfsense_public_key = File.read("pfsense_wg_public_key.txt").strip
    end

    site_b.vm.provision "shell", path: "./scripts/provision-siteb.sh", env: {
      "PFSENSE_WG_PUBLIC_KEY" => pfsense_public_key
    }
  end

  # Monitoring Server VM (Optional)
  config.vm.define "monitoring" do |mon|
    mon.vm.box = "ubuntu/jammy64"
    mon.vm.network :private_network, ip: "192.168.3.10", virtualbox__intnet: "lan_monitoring" # Connects to pfSense OPT2
    mon.vm.provider "virtualbox" do |vb|
      vb.name = "Monitoring-Server"
      vb.memory = "1024"
      vb.cpus = 1
    end
    mon.vm.provision "shell", path: "./scripts/provision-monitoring.sh"
  end
end