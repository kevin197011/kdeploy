## 1. Spec
- [x] 1.1 补充 job-console/job-api/execution-orchestration 的 delta specs（cancel/rerun/limits）
- [x] 1.2 `openspec validate add-web-job-console-controls --strict` 通过

## 2. Data model
- [x] 2.1 runs 表增加 cancel_requested（或等价字段）
- [x] 2.2 迁移脚本可无交互运行

## 3. Orchestrator
- [x] 3.1 支持取消 queued run（worker 取到后跳过）
- [x] 3.2 best-effort 取消 running run（仅标记，不强杀）
- [x] 3.3 支持 rerun（复制参数创建新 run）
- [x] 3.4 资源限制：max_running/max_queue，超限拒绝

## 4. API + UI
- [x] 4.1 API：`POST /api/runs/:id/cancel`、`POST /api/runs/:id/rerun`
- [x] 4.2 UI：run detail 增加 Cancel/Rerun

## 5. Tests & Quality
- [x] 5.1 API：cancel/rerun/limit 的测试
- [x] 5.2 rspec + rubocop 全绿
