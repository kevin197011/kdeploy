# Change: add-automation-output

## Why
当前 `kdeploy` 输出面向人读（banner/彩色表格）很友好，但在脚本化/CI 集成场景里不够方便：

- 日志需要**可机器解析**（JSON）以便做告警、归档、展示。
- 某些场景希望**静默/无 banner** 输出，减少噪音（例如把输出管道给日志系统）。

## What Changes
- 新增 `--no-banner`：执行时不输出 ASCII banner（help/version 保持原样或同样支持该选项）。
- 新增 `--format json`（默认 `text`）：
  - `execute` 输出 JSON，包含 tasks/hosts/status/steps/duration/error。
  - `--dry-run` 时输出计划步骤的 JSON（且不进行网络 side-effects）。
- 文档更新：README 与 help 增加新选项说明与示例。
- 测试：增加 CLI 输出格式相关测试（JSON 可 parse、`--no-banner` 生效）。

## Non-Goals
- 不改变默认输出格式（仍为 text + 彩色）。
- 不在本变更中引入更复杂的日志系统（例如结构化日志后端、分级日志等）。

## Impact
- Affected code:
  - `lib/kdeploy/cli.rb`
  - `lib/kdeploy/output_formatter.rb`（如需复用步骤格式化为 JSON）
  - `lib/kdeploy/help_formatter.rb`
  - `README.md` / `README_EN.md`
  - `spec/cli_spec.rb`（新增/扩展）

