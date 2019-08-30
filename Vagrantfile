# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|

  config.vm.box = "generic/alpine39"
  config.vm.box_check_update = true
  config.vm.hostname = "alpine-apks"
  config.vm.define "alpine-apks"
  config.vm.provider :virtualbox do |vb|
    vb.name = "alpine-apks"
  end  
  config.vm.network "public_network", type: "dhcp", bridge: "en0: Wi-Fi (AirPort)"
end
