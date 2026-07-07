#!/bin/bash
# 按 REQUIREMENTS.md 跑完整功能实测
set -euo pipefail

cd /lab/deploy
/lab/scripts/wait-ssh.sh

run() {
  echo ""
  echo "========== $* =========="
  kdeploy execute deploy.rb "$@"
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

echo "=== FR-DSL-06 apt resources (ubuntu) ==="
run resources_apt --no-banner

echo "=== FR-DSL-06 yum resources (rocky) ==="
run resources_yum --no-banner

echo "=== FR-DSL-05 sync (fast/rsync, ignore, exclude, delete) ==="
run sync_lab --no-banner
run sync_advanced --no-banner

echo "=== FR-DSL-03 targeting (on / roles / assign_task) ==="
run target_web01 --no-banner
run target_web_role --parallel 2 --no-banner
run target_db_role --no-banner
run assigned_echo --no-banner

echo "=== FR-CLI-04 --limit ==="
run smoke --limit ubuntu-web01 --no-banner

echo "=== FR-OUT-02 JSON execute ==="
kdeploy execute deploy.rb smoke --format json --no-banner | jq -e '.results | keys | length >= 1'

echo ""
echo "=========================================="
echo "  KDEPLOY DOCKER LAB: ALL TESTS PASSED"
echo "=========================================="
