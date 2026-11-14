#!/bin/bash

set -euxo pipefail

exec > >(tee /var/log/trendstore-jenkins-setup.log) 2>&1

dnf update -y

dnf install -y \
  java-21-amazon-corretto \
  docker \
  git \
  wget

systemctl enable --now docker

usermod -aG docker ec2-user

wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/redhat-stable/jenkins.repo

rpm --import \
  https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

dnf install -y jenkins

usermod -aG docker jenkins

# Configure 2 GB swap memory before starting Jenkins
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
fi

swapon /swapfile
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Start Jenkins
systemctl enable --now jenkins

echo "TrendStore Jenkins installation completed"
