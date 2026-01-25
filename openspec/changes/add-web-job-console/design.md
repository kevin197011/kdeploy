## Context
本项目已有稳定的执行引擎（DSL/Runner/Executor），但缺少“服务化的作业管理与编排层”。新增 Web 后台需要在不破坏 CLI 体验的前提下，将执行能力封装为可复用的服务接口，并引入持久化以支撑作业与运行记录。

## Goals / Non-Goals
### Goals
- 以最小新增复杂度实现“在线创建作业 + 触发执行 + 查看结果”闭环
- 复用现有执行引擎，不重复实现 SSH/SCP 逻辑
- 输出支持 text/json，方便人看与系统集成
- 全自动、无交互，能跑在 CI 环境（遵循项目约束）

### Non-Goals
- 不做分布式 worker 集群（先单进程/单实例）
- 不做复杂编排（DAG/审批/灰度/回滚）

## High-level Architecture (MVP)
- **Web/API 层**：接收请求、鉴权、校验参数、读写数据库
- **Orchestrator 层**：负责创建 Run 记录、驱动执行、收集结果、更新状态机
- **Execution Adapter**：将“Job/Run 参数”映射到 kdeploy 的任务执行：
  - 支持加载 task file（本地文件/仓库 checkout 的文件）
  - 传入 `limit/parallel/retries/format/no-banner` 等执行参数
  - 结果结构化保存（host->steps/status/error）
- **Persistence (MVP)**：
  - SQLite（内嵌，易部署）
  - 表：jobs、runs、run_host_results、run_logs（或 JSON 字段）

## Decisions
- **Decision: 先做单实例执行（in-process worker）**
  - 理由：MVP 更快闭环；后续可把执行队列外置（Sidekiq/Redis）再扩展。

- **Decision: 以“Run 状态机”作为核心抽象**
  - `queued -> running -> succeeded|failed|cancelled`
  - Host 级别也有状态：`pending/running/succeeded/failed`
  - 理由：UI/API 一致，便于扩展取消/重跑/并发限制。

- **Decision: 输出与存储同时支持 text/json**
  - text：便于用户直接阅读
  - json：便于聚合分析、告警与审计

## Risks / Trade-offs
- **日志敏感信息泄露**
  - Mitigation：默认仅管理员可见；后续加入脱敏与保留期配置。

- **执行资源占用与并发**
  - Mitigation：MVP 限制最大并发；后续引入队列与 worker 扩展。

## Migration Plan
- 第一阶段：只提供 Web/API（MVP），CLI 继续不变
- 第二阶段：引入队列/多 worker、RBAC、DAG 编排等能力

