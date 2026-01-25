## Context
本项目是 Ruby Gem（`kdeploy`），通过 Ruby DSL 定义部署任务并用 SSH/SCP 在多主机并发执行。当前代码已实现核心能力，但存在以下工程化问题：

- DSL 对外“可读取 API”不稳定，导致测试与实现脱节（当前 spec 中出现 `klass.hosts/klass.tasks` 等接口，但实现是 `kdeploy_hosts/kdeploy_tasks`）。
- CLI 的默认值/帮助文案与配置来源存在不一致，增加使用成本。
- debug 输出与错误上下文不足，定位问题不够直接。
- `sync`/模板/路径解析等行为缺少可验证的规格与测试基线。

## Goals / Non-Goals
### Goals
- **定义并固定用户可感知的行为**（通过 OpenSpec 的 requirements+scenarios）。
- **建立最小质量基线**：测试与 lint 能在 CI 中自动运行。
- **减少意外破坏**：尽量通过兼容方式提供稳定 API，不强迫用户改 deploy 文件。

### Non-Goals
- 不扩展为完整编排系统（依赖管理、回滚、发布策略等）。
- 不引入新的基础设施依赖。

## Decisions
- **Decision: 引入“稳定读取接口”以对齐 DSL 与测试**
  - 在 DSL/CLI 内部仍可保留当前存储结构，但对外提供明确的读取方法（例如 `hosts/roles/tasks` 或等价 API），并在 spec 中固定。
  - 理由：让 DSL 的“外部可见面”稳定，便于测试与未来扩展。

- **Decision: 默认值的来源优先级固定为：CLI option > .kdeploy.yml > 代码默认**
  - 例如 `parallel`：若用户显式传 `--parallel` 则覆盖；否则读取 `.kdeploy.yml`；再回退到代码默认值。
  - 理由：用户可预期、便于解释与文档化。

- **Decision: debug 输出只在 `--debug` 开启时展示 stdout/stderr**
  - 默认输出保持简洁（只展示成功/失败、步骤摘要与耗时）。
  - 理由：不打扰日常使用，同时保留排障能力。

## Risks / Trade-offs
- **风险：输出/默认值变更引起用户感知变化**
  - 缓解：以 spec 明确行为；变更保持向后兼容；必要时标注迁移说明。

- **风险：测试覆盖增加导致 CI 变慢**
  - 缓解：优先单元测试；避免引入真实 SSH 依赖（使用 stub/double）。

## Migration Plan
- 若新增 DSL 读取接口：保持旧接口（如存在）可用或提供别名；仅在 major 版本移除。
- 若调整 help 文案：只影响展示，不影响实际行为。

## Open Questions
- 是否计划在近期引入“更强的安全默认值”（例如 `verify_host_key: accept_new`）？本变更默认只做行为定义与一致性对齐。

