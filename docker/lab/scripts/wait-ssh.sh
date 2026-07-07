#!/bin/bash
# 等待目标机 SSH 就绪
set -euo pipefail

KEY=/keys/id_rsa
KEY_HOSTS=(ubuntu-web01 ubuntu-web02 rocky-db01)

chmod 600 "$KEY" 2>/dev/null || true
mkdir -p ~/.ssh
chmod 700 ~/.ssh

for host in "${KEY_HOSTS[@]}"; do
  echo "waiting for $host ..."
  for i in $(seq 1 60); do
    if ssh -i "$KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=3 kdeploy@"$host" 'echo ok' 2>/dev/null; then
      break
    fi
    if [[ $i -eq 60 ]]; then
      echo "timeout waiting for $host" >&2
      exit 1
    fi
    sleep 2
  done
done

echo "key-based targets reachable (debian-pw01 uses password auth via kdeploy)"
