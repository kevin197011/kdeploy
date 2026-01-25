# Change: refactor-core-quality

## Why
当前项目功能已具备可用性，但存在一些一致性/可测试性/可维护性问题（例如 DSL 与测试接口不一致、CLI 帮助与默认值不一致、debug 输出与错误上下文不足等），会降低使用者信任并增加后续迭代成本。

本变更旨在以**最小破坏**方式完成“行为对齐 + 质量基线建立”，让后续功能扩展更稳、更易测、更易维护。

## What Changes
- **建立 OpenSpec 基线能力描述**：补齐 `task-definition` 与 `task-execution` 两个能力的需求与场景（以当前实现为基线，明确需要改进的点）。
- **对齐 DSL 公共接口与测试**：统一 DSL 内部数据结构的可访问方式（例如提供稳定的读取接口），并修复/补充对应测试覆盖。
- **统一 CLI 默认值与帮助文案**：`--parallel` 默认值、`.kdeploy.yml` 默认值、帮助/README 展示保持一致；补充 `--debug` 等已实现但未充分文档化的选项。
- **改进错误与 debug 输出**：
  - 输出中带上关键上下文（host/task/command）。
  - `--debug` 时输出 stdout/stderr，并确保 stderr 颜色语义正确。
- **补强同步/模板/路径解析的可预期性**：
  - `sync` ignore/exclude/delete 行为定义清晰且有测试。
  - 任务文件相对路径解析与 base_dir 逻辑在 spec 中固定下来。
- **CI 质量门禁（最小集）**：在 CI 中跑 `bundle exec rspec`、`bundle exec rubocop`（不新增外部服务依赖）。

## Non-Goals
- 不引入新依赖服务（如 Redis/DB）或复杂的部署编排能力（如编排 DAG、回滚策略等）。
- 不在本变更中增加“全新”部署特性（例如 artifact 管理、远程锁、增量发布等）。

## Impact
- **Affected specs (new)**:
  - `task-definition`
  - `task-execution`
- **Affected code (expected)**:
  - `lib/kdeploy/dsl.rb`
  - `lib/kdeploy/cli.rb`
  - `lib/kdeploy/configuration.rb`
  - `lib/kdeploy/output_formatter.rb`
  - `lib/kdeploy/command_executor.rb`
  - `lib/kdeploy/executor.rb`
  - `spec/*`
  - `.github/workflows/*`（如需要补充 CI job）
- **Compatibility**
  - 目标是保持现有 DSL 用法兼容；若必须调整行为，将在 tasks 里标注并给出迁移方式。

