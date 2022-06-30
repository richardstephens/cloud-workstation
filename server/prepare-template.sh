#!/bin/bash

export RELEASE=jammy
export PASSWORD=$(uuidgen)

qemu-img convert \
 -f qcow2 \
 -O qcow2 \
 /var/lib/libvirt/images/templates/jammy-server-cloudimg-amd64.img \
 /var/lib/libvirt/images/templates/ubuntu.qcow2

qemu-img resize \
  /var/lib/libvirt/images/templates/ubuntu.qcow2 \
  50G
export PASSWORD=$(uuidgen)
echo "#cloud-config
system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: $PASSWORD
chpasswd: { expire: False }
hostname: template

# configure sshd to allow users logging in using password
# rather than just keys
ssh_pwauth: False
package_update: True
package_upgrade: True
apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
packages:
 - python2
 - python-is-python3
 - openjdk-8-jdk
 - gettext
 - libvirt-clients
 - qemu-kvm
 - libvirt-daemon-system
 - libvirt-clients
 - bridge-utils
 - ca-certificates
 - curl
 - gnupg
 - lsb-release
 - docker-ce
 - docker-ce-cli
 - containerd.io
 - docker-compose-plugin

" | sudo tee /var/lib/libvirt/images/templates/cloud-init.cfg



sudo cloud-localds \
  /var/lib/libvirt/images/templates/cloud-init.iso \
  /var/lib/libvirt/images/templates/cloud-init.cfg


sudo virt-install \
  --name template_vm \
  --vcpus 8 \
  --cpu host \
  --memory 64000 \
  --disk /var/lib/libvirt/images/templates/ubuntu.qcow2,device=disk,bus=virtio \
  --disk /var/lib/libvirt/images/templates/cloud-init.iso,device=cdrom \
  --os-variant ubuntu22.04 \
  --virt-type kvm \
  --graphics none \
  --network network=default,model=virtio \
  --import
