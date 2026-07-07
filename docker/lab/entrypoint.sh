#!/bin/bash
set -euo pipefail

install -d -m 700 -o kdeploy -g kdeploy /home/kdeploy/.ssh
if [[ -f /keys/authorized_keys ]]; then
  install -m 600 -o kdeploy -g kdeploy /keys/authorized_keys /home/kdeploy/.ssh/authorized_keys
fi

exec /usr/sbin/sshd -D -e
