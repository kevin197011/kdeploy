# Kdeploy 需求文档

> **权威来源**：本文档描述 Kdeploy 当前应具备的行为，是后续迭代、修 Bug 与交接维护的基线。  
> 若 README 或代码与本文冲突，以本文为准并修正偏差。  
> 版本：**1.3.3**（见 `lib/kdeploy/version.rb`）

---

## 1. 背景与目标

### 1.1 背景

运维与开发团队需要在多台服务器上执行部署、配置同步与命令编排，但不愿在目标机器安装 agent 或守护进程。Kdeploy 以 Ruby Gem 形式提供无代理（agentless）远程执行能力：通过 SSH/SCP（及可选 rsync）完成任务，用 Ruby DSL 描述主机、角色与任务步骤。

### 1.2 目标

- 提供 CLI 工具 `kdeploy`，支持本地/CI 无交互执行
- 支持多主机并发、重试、超时、试运行与 JSON 机器可读输出
- 提供 Chef 风格声明式资源 DSL，降低常见运维操作编写成本

### 1.3 非目标

| 编号 | 非目标 |
|------|--------|
| NG-01 | 不在目标机安装 agent；仅 SSH/SCP/rsync |
| NG-02 | 不做 Chef/Ansible 式收敛（convergence）；无资源状态跟踪与幂等收敛语义 |
| NG-03 | 不提供 Web UI / HTTP API；仅 CLI |
| NG-04 | 不内置密钥/凭据管理服务；敏感信息由用户自行管理 |
| NG-05 | 不保证跨发行版包管理器全覆盖；`package`/`service` 假设 apt/yum + systemd |

---

## 2. 用户与权限

| 角色 | 说明 | 权限边界 |
|------|------|----------|
| **CLI 操作员** | 本机运行 `kdeploy execute` 的用户 | 拥有 SSH 私钥/密码即可连接目标主机；无内置 RBAC |

**约束**：仓库与示例不得提交真实密码、token、私钥。

---

## 3. 功能需求

### 3.1 CLI 命令

#### FR-CLI-01 版本与帮助

- `kdeploy version` / `-v` 输出版本与 Banner
- `kdeploy help [COMMAND]` 输出通用或子命令帮助
- **验收**：`kdeploy version` 退出码 0，输出含 `1.3.3`

#### FR-CLI-02 项目初始化

- `kdeploy init [DIR]` 创建部署项目骨架：`deploy.rb`、`config/`、`README.md`
- 生成的 `deploy.rb` 含 Chef 风格资源示例（package、template、sync 等）
- **验收**：`kdeploy init /tmp/test-kdeploy` 后目录结构完整且 `deploy.rb` 可 `ruby -c` 通过

#### FR-CLI-03 任务执行

- `kdeploy execute TASK_FILE [TASK]` 加载任务文件并执行
- 未指定 `TASK` 时按定义顺序执行**全部**任务；任一任务存在失败主机则**停止**后续任务
- 无匹配主机、未知任务名、空任务文件时退出码 **1**
- 任一主机 `status: :failed` 时进程退出码 **1**
- 任务文件中相对路径以**任务文件所在目录**为基准（`base_dir`），非 CWD
- **验收**：`spec/cli_spec.rb` 覆盖多任务失败停止、退出码、无主机、未知任务

#### FR-CLI-04 execute 选项

| 选项 | 默认 | 说明 |
|------|------|------|
| `--limit HOSTS` | 无 | 逗号分隔主机名，限制执行范围；未知主机名警告 |
| `--parallel N` | 10（可被 `.kdeploy.yml` 覆盖） | 主机级并发数 |
| `--dry-run` | false | 仅打印计划步骤，不建立 SSH |
| `--debug` | false | `run` 步骤输出 stdout/stderr |
| `--no-banner` | false | 抑制 ASCII Banner |
| `--format FORMAT` | `text` | `text` 或 `json` |
| `--retries N` | 0 | 网络类步骤重试次数 |
| `--retry-delay SEC` | 1 | 重试间隔（秒） |
| `--retry-on-nonzero` | false | 非零退出码是否重试 |
| `--timeout SEC` | 无 | 单 host 墙钟超时 |
| `--step-timeout SEC` | 无 | 单 step 超时 |
| `--retry-policy JSON` | 来自配置 | 按步骤类型覆盖重试策略 |
| `--retry-policy-file PATH` | — | `.json` / `.yml` / `.yaml` 策略文件 |

CLI 显式传入的选项优先于 `.kdeploy.yml`。

### 3.2 DSL：主机、角色、任务

#### FR-DSL-01 主机定义 `host(name, **options)`

| 选项 | 必需 | 说明 |
|------|------|------|
| `user` | 是 | SSH 用户名 |
| `ip` | 是 | IP 或主机名 |
| `key` | 否* | 私钥路径 |
| `password` | 否* | SSH 密码 |
| `port` | 否 | SSH 端口，默认 22 |
| `use_sudo` | 否 | 默认对所有命令/upload 使用 sudo |
| `sudo_password` | 否 | 管道给 `sudo -S` |

\* `key` 与 `password` 至少其一（实际连接需要）。

#### FR-DSL-02 角色 `role(name, hosts_array)`

- 将符号角色映射到主机名数组
- 任务可通过 `roles:` 定位主机集合

#### FR-DSL-03 任务 `task(name, on: nil, roles: nil, &block)`

主机定位规则：

1. `on:` 指定主机（字符串或数组）→ 仅这些主机
2. `roles:` 指定角色（符号或数组）→ 角色成员并集
3. 均未指定 → **所有**已定义主机
4. `on`/`roles` 中不存在于 inventory 的主机名**静默跳过**（不报错）

#### FR-DSL-04 任务模块化

- `assign_task(task_name, on:, roles:)` — 事后修改任务定位
- `include_tasks(file_path, roles:, on:)` — `module_eval` 外部文件；仅对**新建且未设 roles/on** 的任务自动赋值
- `inventory { ... }` — 可选分组包装

#### FR-DSL-05 原语步骤

| 方法 | 类型 | 行为 |
|------|------|------|
| `run(cmd, sudo: nil)` | `:run` | 远程 shell；`sudo` 覆盖主机默认 |
| `upload(src, dest)` | `:upload` | SCP 单文件 |
| `upload_template(src, dest, vars)` | `:upload_template` | ERB 渲染后上传 |
| `sync(src, dest, **opts)` | `:sync` | 目录递归同步 |

`sync` 选项：`ignore`/`exclude`（默认 `[]`）、`delete`（默认 false）、`fast`、`parallel`（默认取自配置 `sync_parallel`）。

#### FR-DSL-06 Chef 风格资源

| 资源 | 编译为 | 说明 |
|------|--------|------|
| `package(name, version:, platform: :apt)` | `:run` + sudo | `:apt` → apt-get；`:yum`/`:rpm` → yum |
| `service(name, action:)` | 每个 action 一条 `:run` | `systemctl <action> <name>`；支持 start/stop/restart/reload/enable/disable |
| `template(dest, source:, variables:)` 或 block | `upload_template` | block 内 `TemplateOptions` |
| `file(dest, source:)` | `upload` | |
| `directory(path, mode:)` | `run mkdir -p` (+ 可选 chmod) | 始终 sudo |

资源与原语**按 DSL 书写顺序**展开执行，非 Chef 收敛语义。

### 3.3 执行引擎

#### FR-EXEC-01 并发

- `Runner` 使用 `Concurrent::FixedThreadPool`，大小为 `parallel`（默认 10）
- 单主机内步骤**顺序**执行；首步失败则该主机后续步骤跳过
- `sync` 内部文件上传并行度由 `sync_parallel` 控制（默认 1）

#### FR-EXEC-02 试运行

- `--dry-run` 本地求值任务块，按主机打印计划步骤；**不**实例化 `Runner`、不打开 SSH
- JSON 形态：`{ task, dry_run: true, planned: { host => [steps] } }`

#### FR-EXEC-03 重试

- `CommandExecutor#with_retries` 对 `SSHError`、`SCPError`、`TemplateError` 重试
- 非零退出：仅当 `--retry-on-nonzero` 或 `retry_policy[step_type].retry_on_exit_codes` 包含该码时重试
- 步骤类型：`run`、`upload`、`upload_template`、`sync`
- 策略示例见 `retry_policy.example.json` / `retry_policy.example.yml`

#### FR-EXEC-04 超时

- **Host timeout**（`--timeout`）：轮询标记 `:failed`，消息 `execution timeout after Ns`；超时后尝试 `future.cancel`；**不**保证强杀 SSH
- **Step timeout**（`--step-timeout`）：`Timeout.timeout` 包裹单步，抛出 `StepTimeoutError`
- SSH 连接超时：`ssh_timeout`（默认 30s）

#### FR-EXEC-05 SSH/SCP 行为

- 非零远程退出 → `SSHError`（含 command、exit_status、stdout、stderr）
- 特权路径（`/etc`、`/usr`、`/var` 等）或 `use_sudo`：先上传到 `/tmp/kdeploy_*` 再 `sudo mv`
- `sync` + `fast: true`：本地与远端均有 rsync 时走 rsync，否则回退 SCP 遍历
- `sync` + `delete: true`：删除远端多余文件（尽力而为）

#### FR-EXEC-06 执行结果状态

- 每主机：`success`、`failed`、`unknown`

### 3.4 输出

#### FR-OUT-01 文本输出（默认）

- Banner（除非 `--no-banner`）、任务头、每主机 `✓ ok` / `✗ failed`
- 失败时展示已执行步骤与捕获输出（即使无 `--debug`）
- `--debug` 额外输出 `run` 的 stdout/stderr

#### FR-OUT-02 JSON 输出

- `kdeploy execute ... --format json` 输出：`{ task, results: { host => { status, error, steps } } }`
- 每步含 `type`、`command`、`duration`；`run` 含 stdout/stderr/exit_status；`sync` 含 uploaded/deleted/total/fast_path
- JSON 模式不输出文本汇总；每任务一个 JSON 对象

### 3.5 模板引擎

#### FR-TPL-01 ERB 渲染

- `upload_template` / `template` 资源使用 ERB
- 缺少模板变量 → `ArgumentError`，列出缺失变量名（静态扫描 `<%= var`）
- **验收**：`spec/template_spec.rb`

### 3.6 Shell 补全

#### FR-SHELL-01 安装后补全

- Gem 安装后通过 `post_install` 提示 bash/zsh 补全路径
- 补全文件：`lib/kdeploy/completions/kdeploy.bash`、`.zsh`

---

## 4. 非功能需求

| 编号 | 类别 | 要求 |
|------|------|------|
| NFR-01 | 运行时 | Ruby >= 2.7.0 |
| NFR-02 | CI | 所有脚本与测试须无交互、可全自动运行 |
| NFR-03 | 测试 | 单元测试优先 stub SSH；关键路径有 RSpec 覆盖 |
| NFR-04 | 代码风格 | `# frozen_string_literal: true`；RuboCop 检查 |
| NFR-05 | 并发 | 基于 `concurrent-ruby` 线程池 |
| NFR-06 | 安全默认 | `verify_host_key` 默认 `:never`（便利优先，生产应显式配置） |

---

## 5. 架构概览

```
用户 → kdeploy CLI (Thor)
         ↓
      Runner（线程池，多主机并发）
         ↓
      Executor / CommandExecutor（SSH/SCP/sync）
         ↓
      目标主机
```

### 核心模块

| 模块 | 路径 | 职责 |
|------|------|------|
| CLI | `lib/kdeploy/cli/` | 参数解析、加载任务、调度、输出 |
| DSL | `lib/kdeploy/dsl/` | host/role/task/步骤收集 |
| Runner | `lib/kdeploy/runner/` | 多主机并发编排 |
| Executor | `lib/kdeploy/executor/` | SSH/SCP/sync |
| Template | `lib/kdeploy/template/` | ERB 渲染 |
| Config | `lib/kdeploy/config/` | `.kdeploy.yml` 加载 |
| Output | `lib/kdeploy/output/` | 文本/JSON 格式化 |

### 技术栈

- CLI：Thor、net-ssh、net-scp、concurrent-ruby、pastel、tty-box
- 测试：RSpec；Lint：RuboCop

---

## 6. 配置

### 6.1 `.kdeploy.yml`

从 CWD 向上查找；解析失败时警告并保留默认值。

| 键 | 默认 | 说明 |
|----|------|------|
| `parallel` | 10 | 主机并发 |
| `ssh_timeout` | 30 | SSH 连接超时（秒） |
| `verify_host_key` | `:never` | `always` / `never` / `accept_new` |
| `retries` | 0 | 全局步骤重试 |
| `retry_delay` | 1 | 重试间隔（秒） |
| `host_timeout` | nil | 单 host 超时 |
| `retry_on_nonzero` | false | |
| `sync_fast` | false | sync 默认 fast |
| `step_timeout` | nil | 单 step 超时 |
| `retry_policy` | nil | 按步骤类型策略 |
| `sync_parallel` | 1 | sync 内部上传并行 |

**加载顺序**：CWD 向上查找 `.kdeploy.yml` → 任务文件目录向上查找（覆盖）→ 环境变量 `KDEPLOY_PARALLEL`、`KDEPLOY_SSH_TIMEOUT`（覆盖）。

### 6.2 环境变量（CLI）

| 变量 | 说明 |
|------|------|
| `KDEPLOY_PARALLEL` | 覆盖默认主机并发数 |
| `KDEPLOY_SSH_TIMEOUT` | 覆盖 SSH 连接超时（秒） |

---

## 7. 错误类型

| 类 | 场景 |
|----|------|
| `Kdeploy::Error` | 基类 |
| `TaskNotFoundError` | 未知任务名 |
| `HostNotFoundError` | 保留类型；`--limit` 未知主机仅警告不抛错 |
| `SSHError` | SSH 失败、非零退出 |
| `SCPError` | 上传/sync 失败 |
| `TemplateError` | 模板渲染/上传失败 |
| `StepTimeoutError` | 步骤超时 |
| `ConfigurationError` | Runner 未知命令类型 |
| `FileNotFoundError` | 任务文件或 sync 源目录缺失 |
| `ArgumentError` | 无效 retry_policy、模板参数等 |

---

## 8. 部署与运维

### 8.1 Gem 发布

- `gem build` + RubyGems；CI：`.github/workflows/gem-push.yml`（RSpec + RuboCop，main 推送后发布）

### 8.2 日志

- CLI：stderr/stdout

---

## 9. 安全与已知风险

| 风险 | 说明 | 建议 |
|------|------|------|
| SSH 主机密钥 | 默认不验证 | 生产设置 `verify_host_key: always` 或 `accept_new` |
| sudo 密码 | 可写在 host DSL | 优先 NOPASSWD sudo |
| Host 超时 | 不保证强杀 SSH | 长时间任务可能占用线程池 worker |

---

## 10. 测试验收清单

### 冒烟

```bash
bundle exec rspec                    # 全量测试
bundle exec rubocop                  # 风格检查
kdeploy version                      # CLI 可用
kdeploy execute samples/deploy.rb --dry-run
```

### 回归要点

| 区域 | 测试文件 |
|------|----------|
| DSL / 资源编译 | `spec/kdeploy_spec.rb` |
| CLI dry-run / JSON / 退出码 | `spec/cli_spec.rb` |
| 配置加载 | `spec/configuration_spec.rb` |
| 重试策略 | `spec/retry_spec.rb` |
| 超时 | `spec/timeout_spec.rb` |
| 目录同步 | `spec/sync_spec.rb` |
| SSH 退出码 | `spec/executor_exit_status_spec.rb` |
| 模板变量 | `spec/template_spec.rb` |

### 示例项目

```bash
cd samples
kdeploy execute deploy.rb deploy_web --dry-run
```

### Docker 多机实测（推荐）

仓库提供 Docker Compose 实验环境，覆盖多发行版 SSH 目标机与完整 DSL/CLI 实测：

```bash
cd docker/lab
docker compose up -d --build
docker compose --profile test up --build runner
```

| 目标机 | 发行版 | 实测重点 |
|--------|--------|----------|
| ubuntu-web01/02 | Ubuntu 24.04 | apt、template、sync、并发 |
| rocky-db01 | Rocky Linux 9 | yum `package` |
| debian-pw01 | Debian 12 | 密码 SSH 认证 |

任务定义：`docker/lab/deploy/deploy.rb`。详见 [docker/lab/README.md](../docker/lab/README.md)。

**说明**：容器无 systemd PID 1，`service` 资源以 `--dry-run` 验证编译；`package`/`run`/`sync` 等为实机 SSH 执行。

---

## 11. 变更记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-07-07 | 从 OpenSpec 迁移：整合 CLI、DSL、执行引擎全量需求 |
| 1.1 | 2026-07-07 | 修复：无匹配主机退出码 1、配置从任务目录加载、KDEPLOY_* 环境变量 |
| 1.2 | 2026-07-07 | 移除 Web Job Console；项目聚焦 CLI Gem |
| 1.3 | 2026-07-07 | 新增 `docker/lab` 多发行版 Compose 实测环境 |

---

## 附录 A：需求编号索引

| 前缀 | 领域 |
|------|------|
| FR-CLI | 命令行 |
| FR-DSL | 领域 DSL |
| FR-EXEC | 执行引擎 |
| FR-OUT | 输出格式 |
| FR-TPL | 模板 |
| FR-SHELL | Shell 补全 |
| NG | 非目标 |
| NFR | 非功能 |

Bug / PR 可引用编号，例如：`fix: FR-EXEC-04 host timeout (#123)`。
