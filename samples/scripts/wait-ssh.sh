#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

for vm in web01 web02; do
  echo "waiting for $vm ssh..."
  for i in $(seq 1 60); do
    if vagrant ssh "$vm" -c 'echo ok' &>/dev/null; then
      echo "$vm ready"
      break
    fi
    if [ "$i" -eq 60 ]; then
      echo "timeout waiting for $vm" >&2
      exit 1
    fi
    sleep 2
  done
done
