VM_NAME  := CoreOS Packer
BOX_NAME := CoreOS Box

CHANNEL    ?= alpha
VERSION_ID ?= $(shell curl -Ls http://$(CHANNEL).release.core-os.net/amd64-usr/current/version.txt | grep COREOS_VERSION_ID= | sed -e 's,.*=,,')
BUILD_ID   ?= $(shell date -u '+%Y-%m-%d-%H%M')
BOX_ID := $(CHANNEL)-$(VERSION_ID)

PWD := `pwd`

export CHANNEL
export VERSION_ID

all: clean coreos-$(BOX_ID)-virtualbox.box coreos-$(BOX_ID)-parallels.box

coreos-$(BOX_ID)-virtualbox.box: tmp/CoreOS-$(BOX_ID).vmdk box/change_host_name.rb box/configure_networks.rb box/vagrantfile.tpl
	@echo
	@echo "\t == packing CoreOS release $(VERSION_ID) [$(CHANNEL) channel] for virtualbox =="
	@echo

	vagrant halt -f

	-VBoxManage unregistervm "${BOX_NAME}" --delete
	VBoxManage clonevm "${VM_NAME}" --name "${BOX_NAME}" --register

	VBoxManage storageattach "${BOX_NAME}" --storagectl "IDE Controller" --port 0 --device 0 --medium none
	VBoxManage storageattach "${BOX_NAME}" --storagectl "IDE Controller" --port 1 --device 0 --medium none
	VBoxManage storageattach "${BOX_NAME}" --storagectl "SATA Controller" --port 1 --device 0 --medium none
	VBoxManage storageattach "${BOX_NAME}" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "${HOME}/VirtualBox VMs/${BOX_NAME}/${BOX_NAME}-disk2.vmdk"
	VBoxManage closemedium disk "${HOME}/VirtualBox VMs/${BOX_NAME}/${BOX_NAME}-disk1.vmdk" --delete
	VBoxManage modifyvm "${BOX_NAME}" --ostype Linux26_64

	rm -f coreos-$(BOX_ID).box
	cd box;	\
	vagrant package --base "${BOX_NAME}" --output ../coreos-$(BOX_ID)-virtualbox.box --include change_host_name.rb,configure_networks.rb --vagrantfile vagrantfile.tpl
	VBoxManage unregistervm "${BOX_NAME}" --delete

tmp/CoreOS-$(BOX_ID).vmdk: Vagrantfile oem/coreos-setup-environment tmp/coreos-install tmp/cloud-config.yml
	vagrant destroy -f
	rm -rf "${HOME}/VirtualBox VMs/${VM_NAME}"
	VM_NAME="${VM_NAME}" CHANNEL="${CHANNEL}" VERSION_ID=${VERSION_ID} vagrant up --provider virtualbox --no-provision
	vagrant provision
	vagrant suspend

coreos-$(BOX_ID)-parallels.box: tmp/CoreOS-$(BOX_ID).vmdk parallels/metadata.json parallels/change_host_name.rb parallels/configure_networks.rb parallels/Vagrantfile
	@echo
	@echo "\t == packing CoreOS release $(VERSION_ID) [$(CHANNEL) channel] for parallels =="
	@echo

	vagrant halt -f

	rm -rf "${HOME}/Documents/Parallels/CoreOS.hdd"
	-prl_convert tmp/CoreOS-$(BOX_ID).vmdk --allow-no-os

	-prlctl unregister "${VM_NAME}"
	rm -rf "${HOME}/Documents/Parallels/${VM_NAME}.pvm"
	prlctl create "${VM_NAME}" --ostype linux --distribution linux-2.6 --no-hdd
	mv "${HOME}/Documents/Parallels/CoreOS-${BOX_ID}.hdd" "${HOME}/Documents/Parallels/${VM_NAME}.pvm/"
	prlctl set "${VM_NAME}" --device-add hdd --image "${HOME}/Documents/Parallels/${VM_NAME}.pvm/CoreOS-${BOX_ID}.hdd"
	prlctl set "${VM_NAME}" --device-bootorder "hdd0 cdrom0"

	-prlctl unregister "${BOX_NAME}"
	rm -rf "parallels/${BOX_NAME}.pvm"
	prlctl clone "${VM_NAME}" --name "${BOX_NAME}" --template --dst "${PWD}/parallels"
	prlctl unregister "${VM_NAME}"
	rm -rf "${HOME}/Documents/Parallels/${VM_NAME}.pvm"

	rm -f "parallels/${BOX_NAME}.pvm/config.pvs.backup"
	rm -f "parallels/${BOX_NAME}.pvm/CoreOS-${BOX_ID}.hdd/DiskDescriptor.xml.Backup"

	rm -f coreos-$(BOX_ID)-parallels.box
	cd parallels; tar zcvf ../coreos-$(BOX_ID)-parallels.box *
	prlctl unregister "${BOX_NAME}"
	rm -rf "parallels/${BOX_NAME}.pvm/"

parallels/metadata.json:
	mkdir -p parallels
	echo '{"provider": "parallels"}' > parallels/metadata.json

parallels/change_host_name.rb: box/change_host_name.rb
	mkdir -p parallels
	cp box/change_host_name.rb parallels/change_host_name.rb

parallels/configure_networks.rb: box/configure_networks.rb
	mkdir -p parallels
	cp box/configure_networks.rb parallels/configure_networks.rb

parallels/Vagrantfile: box/vagrantfile.tpl
	mkdir -p parallels
	cp box/vagrantfile.tpl parallels/Vagrantfile

tmp/coreos-install:
	mkdir -p tmp
	curl -Ls https://github.com/coreos/init/raw/master/bin/coreos-install -o tmp/coreos-install.upstream
	@cmp -s tmp/coreos-install.upstream oem/coreos-install || \
			( echo "error: coreos-install script changed at upstream. update it here, or voluntarly drop this check" && \
				exit 1)
	cp oem/coreos-install tmp/coreos-install
	chmod +x tmp/coreos-install

tmp/cloud-config.yml: oem/cloud-config.yml
	mkdir -p tmp
	sed -e "s/%VERSION_ID%/${VERSION_ID}/g" -e "s/%BUILD_ID%/${BUILD_ID}/g" oem/cloud-config.yml > tmp/cloud-config.yml

testup: coreos-$(BOX_ID).box
	@vagrant box add -f coreos coreos-$(BOX_ID).box --provider virtualbox
	@cd test; vagrant destroy -f;  vagrant up --provider virtualbox;

test: testup
	$(run_tests)

ptest: ptestup
	$(run_tests)

ptestup: coreos-$(BOX_ID)-parallels.box
	@vagrant box add -f coreos coreos-$(BOX_ID)-parallels.box --provider parallels
	@cd test; vagrant destroy -f;  vagrant up --provider parallels;

run_tests = @cd test; \
		export DOCKER_HOST_IP=$$(vagrant ssh-config  2>/dev/null | grep -A1 coreos-test | sed -n "s/[ ]*HostName[ ]*//gp"); \
		echo "\n:: nc $${DOCKER_HOST_IP} 8080 ::" ; \
		nc $${DOCKER_HOST_IP} 8080; \
		echo "\n:: docker version ::" ; \
		vagrant ssh -c "docker version" 2>/dev/null; \
		echo "\n:: docker images -t ::" ; \
		vagrant ssh -c "docker images -t" 2>/dev/null; \
		echo "\n:: docker ps -a ::"; \
		vagrant ssh -c "docker ps -a" 2>/dev/null; \
		echo "\n:: cat /etc/os-release ::"; \
		vagrant ssh -c "cat /etc/os-release" 2>/dev/null; \
		echo "\n:: cat /etc/oem-release ::"; \
		vagrant ssh -c "cat /etc/oem-release" 2>/dev/null; \
		echo "\n:: cat /etc/machine-id ::"; \
		vagrant ssh -c "cat /etc/machine-id" 2>/dev/null; \
		echo "\n:: cat /etc/hostname ::"; \
		vagrant ssh -c "cat /etc/hostname" 2>/dev/null; \
		echo "\n:: cat /etc/environment ::"; \
		vagrant ssh -c "cat /etc/environment" 2>/dev/null; \
		echo "\n:: route ::"; \
		vagrant ssh -c "route" 2>/dev/null; \
		echo "\n:: systemctl list-units --no-pager ::"; \
		vagrant ssh -c "systemctl list-units --no-pager" 2>/dev/null; \
		echo "\n:: docker exec `docker ps -l -q` ls -l; uname -a; ::"; \
		vagrant ssh -c 'docker exec `docker ps -l -q` ls -l; uname -a' 2>/dev/null; \
		echo "\n:: "; \
		vagrant halt -f

check:
	@./releaser

clean:
	rm -rf *$(BOX_ID)*.box
	vagrant destroy -f
	cd test; vagrant destroy -f
	rm -rf tmp/
	rm -rf parallels/

.PHONY: clean all
