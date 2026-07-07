#!/bin/bash
# 按 REQUIREMENTS.md 跑 Vagrant 全功能实测
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/kdeploy.sh
source ./scripts/kdeploy.sh

if [[ -x ./scripts/bootstrap.sh ]]; then
  ./scripts/bootstrap.sh
fi
./scripts/wait-ssh.sh

run() {
  echo ""
  echo "========== $* =========="
  kdeploy_cmd execute deploy.rb "$@"
}

json_ok() {
  kdeploy_cmd execute deploy.rb smoke --format json --no-banner | ruby -rjson -e \
    'j = JSON.parse(STDIN.read); abort unless j["results"].keys.length >= 1'
}

echo "=== FR-EXEC-02 dry-run (all hosts) ==="
run smoke --dry-run --no-banner

echo "=== FR-EXEC-02 dry-run JSON ==="
run smoke --dry-run --format json --no-banner | head -c 500
echo "..."

echo "=== FR-DSL syntax dry-run (incl. service) ==="
run dry_run_all_syntax --dry-run --no-banner

echo "=== smoke: all hosts (key + password) ==="
run smoke --no-banner
run smoke_password --no-banner

echo "=== FR-DSL-05 primitives ==="
run primitives --no-banner

echo "=== FR-DSL-06 apt resources (web01) ==="
run resources_apt --no-banner

echo "=== FR-DSL-06 yum resources (web02) ==="
run resources_yum --no-banner

echo "=== FR-DSL-05 sync ==="
run sync_lab --no-banner
run sync_advanced --no-banner

echo "=== FR-DSL-03 targeting ==="
run target_web01 --no-banner
run target_web_role --parallel 2 --no-banner
run target_db_role --no-banner
run assigned_echo --no-banner

echo "=== FR-CLI-04 --limit ==="
run smoke --limit web01 --no-banner

echo "=== FR-OUT-02 JSON execute ==="
json_ok

echo ""
echo "=========================================="
echo "  KDEPLOY VAGRANT LAB: ALL TESTS PASSED"
echo "=========================================="
