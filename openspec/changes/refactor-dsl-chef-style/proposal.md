# Change: refactor-dsl-chef-style

## Why

当前 kdeploy DSL 仅提供底层原语（`run`、`upload`、`upload_template`、`sync`），用户需手写大量 shell 和路径逻辑。Chef、Ansible 等成熟工具采用**资源化 DSL**，以声明式方式描述期望状态（如「安装包」「启动服务」「部署模板」），可读性更好、复用性更高、错误更易排查。

本变更旨在为 kdeploy 引入类似 Chef 风格的**资源型 DSL 封装**，在保持现有原语兼容的前提下，让任务定义更贴近声明式、更易维护。

## What Changes

- **新增资源型 DSL**：在任务块内支持 `package`、`service`、`template`、`file`、`directory` 等资源方法。
- **资源映射为底层原语**：每个资源内部编译为等价的 `run`/`upload`/`upload_template` 命令序列，不改变 Runner/Executor 执行链路。
- **平台适配策略**：资源默认面向 apt/Ubuntu + systemd；支持通过 `platform:` 或配置指定 yum/RedHat 等，差异化命令生成。
- **保留原语**：`run`、`upload`、`upload_template`、`sync` 保持不变，用户可继续混用资源与原语。
- **文档与示例**：README 与 sample 增加资源 DSL 用法示例，并逐步迁移 sample tasks 为资源风格（可选）。

### 非目标（本次不变）

- 不实现 Chef 的 `notifies`/`subscribes` 依赖与触发机制。
- 不实现 Chef 的 `only_if`/`not_if` 条件守卫（可后续单独提案）。
- 不引入 YAML/Ansible 风格；仍以 Ruby DSL 为主。

## Impact

- **Affected specs**:
  - `task-definition`（MODIFIED：补充资源 DSL 为任务内合法命令）
  - `resource-dsl`（ADDED：新能力，描述各资源语义与行为）
- **Affected code**:
  - `lib/kdeploy/dsl.rb`（新增资源方法，编译为原语）
  - `lib/kdeploy/command_grouper.rb`（如新增资源类型需参与分组展示）
  - `lib/kdeploy/cli.rb`（dry-run/JSON 输出需识别资源步骤）
  - `sample/tasks/*.rb`（可选迁移示例）
  - `README.md`、`README_EN.md`
- **Compatibility**:
  - 完全向后兼容：现有任务文件无需修改；资源 DSL 为增量能力。
