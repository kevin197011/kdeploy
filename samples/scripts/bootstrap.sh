#!/bin/bash
# AVF 无 provision；通过 vagrant ssh 引导（DNS / 时钟 / 包）
set -euo pipefail

cd "$(dirname "$0")/.."

bootstrap_web01() {
  host_date=$(date -u '+%Y-%m-%d %H:%M:%S')
  vagrant ssh web01 -c "bash -s" <<EOF
set -e
echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf >/dev/null
sudo date -u -s '${host_date}' || true
echo 'Acquire::Check-Valid-Until "false";' | sudo tee /etc/apt/apt.conf.d/99lab >/dev/null
sudo rm -f /etc/apt/sources.list
export DEBIAN_FRONTEND=noninteractive
if ! command -v rsync >/dev/null || ! command -v curl >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y rsync curl
fi
echo "vagrant ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/vagrant >/dev/null
echo web01-bootstrap-ok
EOF
}

bootstrap_web02() {
  host_date=$(date -u '+%Y-%m-%d %H:%M:%S')
  vagrant ssh web02 -c "bash -s" <<EOF
set -e
echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf >/dev/null
sudo date -u -s '${host_date}' || true
if ! command -v rsync >/dev/null; then
  sudo dnf install -y openssh-server rsync curl
fi
echo "vagrant ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/vagrant >/dev/null
sudo useradd -m kdeploy 2>/dev/null || true
echo 'kdeploy:kdeploy' | sudo chpasswd
echo 'kdeploy ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/kdeploy >/dev/null
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo tee /etc/ssh/sshd_config.d/50-kdeploy.conf >/dev/null <<'SSHD'
Match User kdeploy
    PasswordAuthentication yes
    AuthenticationMethods password
SSHD
sudo systemctl restart sshd
echo web02-bootstrap-ok
EOF
}

bootstrap_web01
bootstrap_web02
