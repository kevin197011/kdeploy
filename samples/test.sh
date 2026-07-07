#!/bin/bash
# 启动两台 Vagrant VM 并跑 kdeploy 全功能实测
set -euo pipefail

cd "$(dirname "$0")"

echo "🚀 Kdeploy Vagrant Lab"
echo "======================"

if ! command -v vagrant &>/dev/null; then
  echo "❌ Vagrant not installed: https://www.vagrantup.com/" >&2
  exit 1
fi

# shellcheck source=scripts/kdeploy.sh
source ./scripts/kdeploy.sh
if ! kdeploy_cmd version &>/dev/null; then
  echo "❌ kdeploy not found. From repo root: rake run" >&2
  exit 1
fi

VAGRANT_ARGS=()
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
  if vagrant plugin list 2>/dev/null | grep -q vagrant-provider-avf; then
    echo "▶ Apple Silicon: using AVF + ARM64 boxes (sodini-io/*-arm64)"
    VAGRANT_ARGS=(--provider avf)
  else
    echo "⚠️  M 系列 Mac 建议安装 AVF 插件（比 VirtualBox 稳定）：" >&2
    echo "   vagrant plugin install vagrant-provider-avf" >&2
    echo "   vagrant box add sodini-io/ubuntu-24.04-arm64 --provider avf" >&2
    echo "   vagrant box add sodini-io/rocky-9-arm64 --provider avf" >&2
    echo "▶ Fallback: VirtualBox + bento/* (arm64)" >&2
    VAGRANT_ARGS=(--provider virtualbox)
  fi
else
  VAGRANT_ARGS=(--provider virtualbox)
fi

echo "▶ Starting VMs (web01 Ubuntu 768MB + web02 Rocky 512MB)..."
# AVF 并行 up 可能触发 cloud-init seed 冲突，逐台启动
vagrant up web01 "${VAGRANT_ARGS[@]}"
vagrant up web02 "${VAGRANT_ARGS[@]}"

chmod +x scripts/wait-ssh.sh scripts/run-tests.sh scripts/bootstrap.sh
./scripts/run-tests.sh
