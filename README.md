this is based in [YungSang](https://github.com/YungSang/coreos-packer)'s original work and research, and is _just_ a refactoring to suit my particular tastes.  

# CoreOS Packer for Vagrant Box

a tool for building [CoreOS](http://www.coreos.com) Vagrant VirtualBox and Parallels boxes

## How to Build

```
$ CHANNEL=$channel VERSION_ID=$version_id make 
```
where **$channel** is one of *alpha*, *beta* or *stable* (default is _alpha_) and **$version** a given CoreOS release (the default is the latest one). see [here](https://coreos.com/releases/) for what's available
 
in order to build all the latest versions for all channels one would do ... 

```
for channel in stable beta alpha; do \
	make _clean; \
    CHANNEL=$channel make; \
    done;
```


## How to Use

```
$ vagrant box add coreos-beta coreos-beta-522.5.0-parallels.box
$ vagrant init coreos-beta
$ vagrant up
```

Or, manually

```
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "AntonioMeireles/coreos"

  config.vm.network "forwarded_port", guest: 2375, host: 2375

  config.vm.network "private_network", ip: "192.168.33.10"

  config.vm.synced_folder ".", "/home/core/vagrant", id: "core", type: "nfs", mount_options: ["nolock", "vers=3", "udp"]

  config.vm.provision :docker do |d|
    d.pull_images "yungsang/busybox"
    d.run "simple-echo",
      image: "yungsang/busybox",
      args: "-p 8080:8080",
      cmd: "nc -p 8080 -l -l -e echo hello world!"
  end

  config.vm.network :forwarded_port, guest: 8080, host: 8080
end
```

```
$ vagrant up
$ docker version
$ docker images -t
$ docker ps -a
$ nc localhost 8080
hello world!
```
## Pre-built boxes

boxes built with this tool are available at Vagrant's Atlas [here](https://atlas.hashicorp.com/AntonioMeireles/).

## Licensing
[![CC0](http://i.creativecommons.org/p/zero/1.0/88x31.png)](http://creativecommons.org/publicdomain/zero/1.0/)  

To the extent possible under law, the person who associated CC0 with this work has waived all copyright and related or neighbouring rights to this work.
