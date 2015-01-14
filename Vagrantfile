# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  channel = ENV['CHANNEL']
  version_id = ENV['VERSION_ID']

  config.vm.define "coreos-packer"
  config.vm.hostname = "coreos-packer"

  config.vm.box = "hashicorp/precise64"

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider :virtualbox do |vb|
    vb.name = ENV['VM_NAME'] || "CoreOS Packer"
    vb.cpus = 1
    vb.memory = 1024

    # Create and attach a target HDD
    vmdk = "tmp/CoreOS-%s-%s.vmdk" % [channel, version_id]
    vb.customize [
      "createhd",
      "--filename", vmdk,
      "--size", "40960",
      "--format", "VMDK",
    ]
    vb.customize [
      "storageattach", :id,
      "--storagectl", "SATA Controller",
      "--port", "1",
      "--device", "0",
      "--type", "hdd",
      "--medium", vmdk,
    ]
    (1..8).each do |i|
      vb.customize [
        "modifyvm", :id,
        "--nictype#{i}", "virtio"
      ]
    end
  end

  config.vm.provision :shell do |s|
    s.inline = <<-EOT
      echo Installing CoreOS #{channel}/#{version_id}
      sudo /vagrant/tmp/coreos-install -d /dev/sdb -C #{channel} -V #{version_id} 2> /dev/null
      sudo mount /dev/sdb6 /mnt
      sudo cp /vagrant/tmp/cloud-config.yml /mnt/
      sudo mkdir -p /mnt/bin
      sudo cp /vagrant/oem/coreos-setup-environment /mnt/bin/
      sudo cp /vagrant/oem/motd /mnt/
      sudo cp /vagrant/tmp/motdgen /mnt/bin/
      sudo umount /mnt
    EOT
  end
end
