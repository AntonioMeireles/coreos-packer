this is based in [YungSang](https://github.com/YungSang/coreos-packer)'s original work and research. it's _just_ a refactoring to suit my own tastes. 
_____
# CoreOS Packer for Vagrant Box
tooling to build [CoreOS](http://www.coreos.com) Vagrant VirtualBox and Parallels boxes
---
for tips on CoreOS and Vagrant general usage do look at [coreos-vagrant](https://github.com/coreos/coreos-vagrant)
(together with [this](https://github.com/coreos/coreos-vagrant/pull/199/files) pull request).
## How to Build

```bash
$ CHANNEL=$channel VERSION_ID=$version_id make
```
where **$channel** is one of *alpha*, *beta* or *stable* (default is _alpha_) and **$version**
a given CoreOS release (the default is the _latest_ one). see [here](https://coreos.com/releases/)
for what's available

so, in order to build all the latest versions of all channels one would just have to do ...

```bash
$ for channel in stable beta alpha; do \
	make _clean; \
   CHANNEL=$channel make; \
done;
```


## How to Use

```bash
$ vagrant box add coreos-beta coreos-beta-522.5.0-parallels.box --provider parallels
$ vagrant init coreos-beta
$ vagrant up --provider parallels
```

Or, manually

```ruby
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "AntonioMeireles/coreos"

  config.vm.network "forwarded_port", guest: 2375, host: 2375

  config.vm.network "private_network", ip: "192.168.33.10"

  config.vm.synced_folder ".", "/home/core/vagrant", id: "core", type: "nfs", mount_options: ["nolock", "vers=3", "udp"]

  config.vm.network :forwarded_port, guest: 8080, host: 8080
end
```

```bash
$ vagrant up
```

## Pre-built boxes

up to date boxes built with this tool are available at Vagrant's Atlas [here](https://atlas.hashicorp.com/AntonioMeireles/).

## Licensing
[![CC0](http://i.creativecommons.org/p/zero/1.0/88x31.png)](http://creativecommons.org/publicdomain/zero/1.0/)

To the extent possible under law, the person who associated [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
with this work has waived all copyright and related or neighbouring rights to this work.
