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
cat <<EOF | tee /var/lib/libvirt/images/templates/cloud-init.cfg
#cloud-config
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
 - at
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
runcmd:
 - sudo adduser ubuntu kvm
 - [curl, "-L", "https://dl.k8s.io/release/v1.24.0/bin/linux/amd64/kubectl", "-o", /usr/local/bin/kubectl]
 - [chmod, "+x", /usr/local/bin/kubectl]
 - [curl, "-L", "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64", "-o", /usr/local/bin/minikube]
 - [chmod, "+x", /usr/local/bin/minikube]
 - [sudo, "-u", ubuntu, minikube, config, set, driver, kvm2]
 - [curl, "-L", "https://github.com/bazelbuild/bazelisk/releases/download/v1.11.0/bazelisk-linux-amd64", "-o", /usr/local/bin/bazel]
 - [chmod, "+x", /usr/local/bin/bazel]
 - mkdir /run/inst
 - [curl, "-L", "https://go.dev/dl/go1.18.3.linux-amd64.tar.gz", "-o", "/run/inst/go.tgz"]
 - [rm, "-rf", "/usr/local/go"]
 - [tar, "-C", "/usr/local", "-xzf", "/run/inst/go.tgz"]
 - [rm, /run/inst/go.tgz]
 - "echo \"export PATH=\\\\\$PATH:/usr/local/go/bin\" >> /home/ubuntu/.profile"
 - "sudo cloud-init clean"
 - [curl, "-L", "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-368.0.0-linux-x86_64.tar.gz", "-o", "/run/inst/gcloud.tgz"]
 - "sudo tar xzf /run/inst/gcloud.tgz -C /usr/local/bin"
 - "echo \"export PATH=/usr/local/bin/google-cloud-sdk/bin:\\\\\$PATH\" >> /home/ubuntu/.profile"
 - "echo \"sudo cloud-init clean; sudo shutdown -P 15\" | at now + 1 min"
EOF



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
