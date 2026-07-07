# Docker Lab — Kdeploy 功能实测

多发行版 Linux 目标机 + 自动化 Runner，覆盖 [docs/REQUIREMENTS.md](../../docs/REQUIREMENTS.md) 中的 DSL、执行与 CLI 能力。

## 拓扑

| 服务 | 发行版 | 用途 |
|------|--------|------|
| `ubuntu-web01` | Ubuntu 24.04 | apt、`package`、nginx、`template`/`file`/`directory`、sync |
| `ubuntu-web02` | Ubuntu 24.04 | 并发第二台、`assign_task`、`--parallel` |
| `rocky-db01` | Rocky Linux 9 | `package` + `platform: :yum` |
| `debian-pw01` | Debian 12 | SSH **密码**认证（`password:`） |
| `runner` | Ruby 3.2 | 安装本仓库 gem，执行实测脚本 |

SSH 密钥由 `keygen` 服务一次性生成，挂载到各目标机与 runner。

## 快速开始

```bash
# 项目根目录
cd docker/lab

# 启动目标机
docker compose up -d --build

# 一键跑完全部实测
docker compose --profile test up --build runner
```

或本地已有 kdeploy 时，进入 runner 容器手动执行：

```bash
docker compose exec -it ubuntu-web01 bash   # 调试目标机
docker compose run --rm runner /lab/scripts/run-tests.sh
```

## 实测任务与需求映射

| 任务 | 覆盖 |
|------|------|
| `smoke` | 全主机连通、`run` |
| `smoke_password` | 密码认证主机 |
| `dry_run_all_syntax` | 全部资源/原语 **dry-run**（含 `service` 编译） |
| `primitives` | `upload`、`upload_template` |
| `resources_apt` | `package`、`directory`、`template`、`file`、nginx |
| `resources_yum` | `package` + `:yum` |
| `sync_lab` / `sync_advanced` | `sync` ignore/exclude/delete/fast/parallel |
| `target_*` / `assigned_echo` | `on`、`roles`、`assign_task` |
| 脚本额外 | `--dry-run`、`--format json`、`--limit`、`--parallel` |

## 说明

- 容器内**无 systemd PID 1**，`service` 资源通过 `dry_run_all_syntax --dry-run` 验证 DSL 编译；实机部署请用 VM/物理机。
- 实测任务文件：`deploy/deploy.rb`（独立于 `samples/`，专用于 Docker 网络主机名）。

## 清理

```bash
docker compose down -v
```
