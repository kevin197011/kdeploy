# Change: add-web-job-console-controls

## Why
当前 Web Job Console 已能“创建作业 + 触发执行 + 查看结果”，但还缺少两个上线常见能力：

- **取消/重跑**：避免误触发、以及失败后快速重跑
- **资源限制**：防止无限排队/无限并发导致资源耗尽

## What Changes
- **取消（Cancel）**：
  - queued 状态可取消（保证生效）
  - running 状态提供 best-effort 取消（MVP：只标记取消请求，若执行引擎不支持强制中断则可能在本次 run 结束后生效）
- **重跑（Rerun）**：
  - 基于既有 Run 参数创建新 Run（便于重复执行）
- **资源限制（MVP）**：
  - 最大 running runs（默认 1，可配置）
  - 最大 queued runs（默认 100，可配置）
  - 超限返回 429（API）或提示错误（UI）
- UI 增加按钮：Run detail 页面支持 Cancel/Rerun
- API 增加端点：`POST /api/runs/:id/cancel`、`POST /api/runs/:id/rerun`

## Non-Goals
- 不做精确的“强制中断 SSH 命令”能力（需要更深层的执行引擎改造）
- 不做复杂的配额系统/多租户限流

## Impact
- Affected code:
  - `web/app/app.rb`
  - `web/lib/orchestrator.rb`
  - `web/lib/models.rb`
  - `web/db/migrate/*`（新增 migration）
  - `web/views/run_detail.erb`
  - `spec/web/*`

