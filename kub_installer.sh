#!/bin/bash

# enable kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# configure kernel modules to load on boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# set system configurations
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Add Docker GPG key to keyring
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

# Add Docker repository to sources list
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
sudo apt update

# Install containerd.io package
sudo apt install containerd.io

# Reload systemctl daemon
sudo systemctl daemon-reload

# Enable and start containerd service
sudo systemctl enable --now containerd
sudo systemctl start containerd

# Create directory for containerd config
sudo mkdir -p /etc/containerd

# Configure containerd with default settings
sudo su -c "containerd config default | tee /etc/containerd/config.toml"

# Modify containerd config to use systemd cgroups
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd to apply new settings
sudo systemctl restart containerd

# Allow necessary ports through UFW firewall
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10259/tcp
sudo ufw allow 10257/tcp

# Update package lists
sudo apt-get update

# Install Kubernetes packages
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Hold package versions
sudo apt-mark hold kubelet kubeadm kubectl

# Kubeadm Package pull
sudo kubeadm config images pull
