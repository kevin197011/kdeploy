#!/bin/bash
# 优先使用仓库本地 kdeploy（samples/ 的父目录）
kdeploy_cmd() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  if [[ -f "$root/exe/kdeploy" ]]; then
    ruby -I "$root/lib" "$root/exe/kdeploy" "$@"
  else
    command kdeploy "$@"
  fi
}
