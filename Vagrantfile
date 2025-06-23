
Vagrant.configure("2") do |config|
  config.vm.define "pfsense" do |pfsense|
    pfsense.vm.box = "kennyl/pfsense"
    pfsense.vm.hostname = "pfsense"
    pfsense.vm.network "private_network", ip: "192.168.110.30"
    pfsense.vm.synced_folder ".", "/vagrant", disabled: true
    pfsense.vm.provision "shell", path: "scripts/pfsense.sh"
  end

  config.vm.define "siteA" do |siteA|
    siteA.vm.box = "ubuntu/trusty64"
    siteA.vm.hostname = "siteA"
    siteA.vm.network "private_network", ip: "192.168.110.21"
    siteA.vm.provision "shell", path: "scripts/siteA.sh"
  end

  config.vm.define "siteB" do |siteB|
    siteB.vm.box = "ubuntu/trusty64"
    siteB.vm.hostname = "siteB"
    siteB.vm.network "private_network", ip: "192.168.110.22"
    siteB.vm.provision "shell", path: "scripts/siteB.sh"
  end

end
