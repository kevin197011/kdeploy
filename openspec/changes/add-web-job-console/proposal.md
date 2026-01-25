# Change: add-web-job-console

## Why
当前 `kdeploy` 以 CLI/DSL 方式使用，适合工程师在本地/CI 中调用；但在“运维/发布/批量作业”场景下，常见需求是：

- 在线管理作业（保存 deploy 脚本、参数模板、目标主机/角色选择）
- 可视化编排与批量执行（一次触发多个任务/多个环境）
- 统一审计（谁在什么时候跑了什么，结果如何，日志可回溯）
- 更易集成（通过 Web/API 调用，而不直接给所有人 SSH 权限）

因此需要基于现有执行引擎（DSL/Runner/Executor）新增一个**Web 作业管理后台**，提供在线编排与执行能力。

## What Changes
- 新增一个 Web 服务（“作业管理后台”），提供：
  - 作业定义管理：任务文件来源/变量/默认参数/标签等
  - 执行编排：选择作业 + 任务 + 目标（host/role/limit）+ 并发/重试/输出格式
  - 运行记录：运行状态、开始/结束时间、每台主机结果、日志（text/json）
  - 基本的访问控制（最小可用：本地管理员账户或 token；后续可扩展到 SSO）
- 提供 HTTP API（供前端与外部系统调用），并提供一个 Web UI 管理后台。
- 复用现有 `kdeploy` 引擎：执行仍走 `Runner/Executor`，Web 侧主要负责“持久化 + 编排 + 触发 + 展示”。

## MVP Scope (recommended)
为避免一次性做成“大而全”的编排平台，本 change 的 MVP 建议聚焦：

- 作业 = 一个部署仓库（或一个 task 文件）+ 变量模板（键值）+ 可选的 `task_name`
- 运行 = 选择作业 + 选择 task + 选择 limit/parallel/retries/format + 执行并记录结果
- UI = 作业列表/编辑、运行列表/详情、单次运行一键重跑

## Non-Goals
- 不实现复杂 DAG 编排、依赖关系、回滚策略、审批流（可后续扩展）。
- 不在 MVP 中引入多租户/细粒度 RBAC（先有最小可用的 auth）。
- 不在 MVP 中实现分布式执行集群（先单实例 worker）。

## Impact
- New capabilities (OpenSpec deltas):
  - `job-console`（Web UI 行为与页面）
  - `job-api`（HTTP API 合约）
  - `execution-orchestration`（编排/运行记录/状态机）
- Expected new code areas:
  - `web/`（或 `server/`）：Web 服务与 API
  - `web/ui/`：前端 UI（或服务端渲染）
  - `db/`：持久化（SQLite for MVP）
  - `docker-compose.yml` / `scripts/`（如需要，需遵循项目“非交互、CI 可运行”约束）
- Security considerations:
  - 运行日志可能包含敏感信息；需有脱敏策略/访问控制/保留期策略。

