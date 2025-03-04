script_jammy = <<-SCRIPT
  if [ ! -f /opt/puppetlabs/bin/puppet ]; then
    sudo wget --quiet https://apt.puppetlabs.com/puppet7-release-jammy.deb
    sudo dpkg -i puppet7-release-jammy.deb
    sudo apt-get update
    sudo apt-get install puppet -y
    sudo apt-get update
  fi
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.hostname = "raspberry.example.org"
  config.vm.provider "virtualbox" do |vb|
    vb.name = "rpinew"
  end

  #config.vm.synced_folder "hieradata/", "/tmp/vagrant-puppet/hieradata"
  config.vm.provision "shell", inline: script_jammy
  config.vm.provision "puppet" do |puppet|
    #puppet.hiera_config_path = "hiera.yaml"
    puppet.working_directory = "/tmp/vagrant-puppet"
    puppet.module_path = "modules"
    puppet.manifest_file = "raspberry.pp"
#    puppet.options = "--debug --verbose"
  end
end
