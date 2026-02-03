# Design: refactor-dsl-chef-style

## Context

kdeploy 当前 DSL 提供 `run`、`upload`、`upload_template`、`sync` 四个底层原语。用户编写任务时需手写大量 shell 和路径逻辑（如 `apt-get install`、`systemctl start`、`tee` 生成 systemd unit 等），风格接近 Ansible 的 raw/shell 模块，而非 Chef 的声明式资源。Chef 与 Ansible 的核心优势在于：资源/模块封装了平台差异和幂等语义，用户只需声明期望状态。

本设计参考 Chef Recipe DSL 和 Ansible 模块结构，为 kdeploy 增加资源型 DSL，在保持 Ruby DSL 语法的前提下提升可读性与复用性。

## Goals / Non-Goals

**Goals:**
- 提供 Chef 风格的资源 DSL：`package`、`service`、`template`、`file`、`directory`
- 资源编译为底层原语，不修改 Runner/Executor 执行模型
- 保持向后兼容，现有任务无需修改
- 默认支持 apt + systemd；预留平台扩展点（apt/yum 等）

**Non-Goals:**
- 不实现 Chef 的 `notifies`/`subscribes`（依赖编排复杂，后续单独提案）
- 不实现 Chef 的 `only_if`/`not_if`（可后续单独提案）
- 不引入 YAML/Ansible 格式；保持 Ruby DSL 为主

## Decisions

### 1. 资源编译为原语（无新执行路径）

- 每个资源方法在 `create_task_block` 内执行时，向 `@kdeploy_commands` 追加一条或多条等价原语。
- 例如 `package 'nginx'` 追加 `{ type: :run, command: 'apt-get update && apt-get install -y nginx', sudo: true }`。
- 不新增 `:package`、`:service` 等类型到 Runner/CommandExecutor；Runner 仍只识别 `:run`、`:upload`、`:upload_template`、`:sync`。
- 优点：实现简单、无需改动 Executor/CLI 输出逻辑；缺点：dry-run/JSON 中展示为 run/upload，无法直接区分“资源 vs 原始 run”。

### 2. 资源 API 设计（Chef-like 语法）

- **package**：`package 'nginx'` 或 `package 'nginx', version: '1.18'`
- **service**：`service 'nginx', action: [:enable, :start]`（支持 `:start`, `:stop`, `:restart`, `:reload`, `:enable`, `:disable`）
- **template**：`template '/etc/nginx/nginx.conf' do source './config/nginx.conf.erb'; variables(...); end`（与现有 `upload_template` 语义一致，封装为资源）
- **file**：`file '/etc/nginx/app.conf', source: './config/app.conf'`（等价于 upload）
- **directory**：`directory '/etc/nginx/conf.d', mode: '0755'`（等价于 `mkdir -p`）

### 3. 平台与提供者

- 默认平台：apt（Ubuntu/Debian）+ systemd。
- `package` 默认生成 `apt-get update && apt-get install -y <name>`；可选 `platform: :yum` 生成 `yum install -y <name>`。
- `service` 默认生成 `systemctl <action> <name>`；如无 systemctl，可 fallback 到 `service <name> <action>`。
- 平台可通过 `platform:` 参数或全局配置（如 `.kdeploy.yml` 中的 `platform: apt`）指定。

### 4. 幂等与行为

- kdeploy 为无代理 SSH 工具，不具备 Chef 的“状态检测 + 按需执行”能力。
- 资源始终执行命令（如 `apt-get install`、`systemctl start`），不实现“已安装则跳过”“已启动则跳过”等幂等检测。
- 用户可通过 `run` 原语配合 `|| true` 或条件 shell 自行实现幂等；或在后续提案中增加 `only_if`/`not_if` 支持。

### 5. 资源 vs 原语的 dry-run 展示

- 若资源编译为 run/upload，dry-run 中展示为原始命令或 upload 路径。
- 可选：资源方法追加 `type: :run` 时，在 `command` 前加 `# resource: package[name]` 等注释，便于阅读。此为可选增强，不在 MVP 必须范围。

## Alternatives Considered

| 选项 | 说明 | 弃用原因 |
|------|------|----------|
| 新增独立资源执行路径 | Runner 识别 `:package`、`:service` 等，CommandExecutor 新增对应 handler | 改动面大，需修改 CLI/JSON 输出等 |
| 完全照搬 Chef 语法 | 使用 `do...end` 块 + 属性 | 实现复杂，kdeploy 无 Chef 的 converge 阶段 |
| 仅提供 helper 方法 | 如 `install_package('nginx')` 返回 shell 字符串 | 语义弱，不如资源 DSL 清晰 |

## Risks / Trade-offs

- **平台假设**：默认 apt + systemd 可能不适配 CentOS/RHEL 等，需通过 `platform:` 扩展。
- **幂等缺失**：资源每次执行都会跑命令，可能带来多余日志或短暂阻塞；用户可通过 shell 条件自行控制。

## Migration Plan

1. 实现资源 DSL，保持原语不变。
2. 更新 README 与 sample，展示资源写法。
3. 可选：逐步将 sample/tasks/nginx.rb 等迁移为资源风格，作为参考示例。
4. 无破坏性变更，无需迁移脚本。

## Open Questions

- 是否在 dry-run 中为资源步骤增加可读性标注（如 `# resource: package[nginx]`）？
- 是否需要支持 `template` 的 `owner`/`group`/`mode` 属性（需额外 chown/chmod 步骤）？
