# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "debian/bookworm64"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.56.10"

  # Provisionner avec Puppet
  config.vm.define :web do |web_config|
      web_config.vm.provision "shell", inline: "sudo apt-get update && sudo apt-get install -y puppet"
      web_config.vm.provision "puppet" do |puppet|
            puppet.manifests_path = "manifests"
            puppet.module_path = "modules"
            puppet.manifest_file = "raspberry.pp"
      end
  end
  config.vm.synced_folder ".", "/vagrant", disabled: true
end

