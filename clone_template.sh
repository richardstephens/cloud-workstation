#!/usr/bin/env bash

set -e
set +x

VM_NAME=$( uuidgen |cut -d '-' -f 1)
TEMPLATE=/var/lib/libvirt/images/templates/ubuntu.qcow2
PASSWORD=$VM_NAME

echo "Creating $VM_NAME"
sudo mkdir /var/lib/libvirt/images/$VM_NAME \
  && sudo qemu-img convert \
  -f qcow2 \
  -O qcow2 \
  "$TEMPLATE" \
  "/var/lib/libvirt/images/$VM_NAME/root-disk.qcow2"

sudo qemu-img resize \
  /var/lib/libvirt/images/$VM_NAME/root-disk.qcow2 \
  30G


echo "#cloud-config
system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: $PASSWORD
chpasswd: { expire: False }
hostname: $VM_NAME

# configure sshd to allow users logging in using password 
# rather than just keys
ssh_pwauth: True
" | sudo tee /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

sudo cloud-localds \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.iso \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

sudo virt-install \
  --name $VM_NAME \
  --vcpus 8 \
  --cpu host \
  --memory 64000 \
  --disk /var/lib/libvirt/images/$VM_NAME/root-disk.qcow2,device=disk,bus=virtio \
  --disk /var/lib/libvirt/images/$VM_NAME/cloud-init.iso,device=cdrom \
  --os-variant ubuntu22.04 \
  --virt-type kvm \
  --graphics none \
  --network network=default,model=virtio \
  --import \
  --noreboot \
  --noautoconsole

