## 1. Spec
- [x] 1.1 为 `job-console` / `job-api` / `execution-orchestration` 编写 spec deltas（每条 Requirement 至少 1 个 Scenario）
- [x] 1.2 `openspec validate add-web-job-console --strict` 通过

## 2. MVP Architecture & Scaffolding
- [x] 2.1 选择 Web 技术栈与目录结构（优先 Ruby 轻量方案，避免过度复杂）
- [x] 2.2 定义数据模型（jobs/runs/run_host_results/...）与迁移策略（SQLite for MVP）
- [x] 2.3 定义运行状态机与取消/重跑最小语义

## 3. API
- [x] 3.1 Job CRUD API（创建/更新/列表/详情）
- [x] 3.2 Run API（触发执行、查询状态、查询详情、获取日志/结果）
- [x] 3.3 Auth（最小可用：token 或本地管理员）

## 4. UI
- [x] 4.1 作业列表/新建/编辑页面
- [x] 4.2 运行列表/详情页面（按 host 展示状态、步骤、耗时）
- [x] 4.3 一键重跑/取消（MVP：取消可先做 best-effort）

## 5. Execution Integration
- [x] 5.1 将 job/run 参数映射到 `kdeploy` 执行引擎（limit/parallel/retries/format）
- [x] 5.2 输出落库（text/json），并提供下载接口
- [x] 5.3 资源限制与并发控制（MVP：全局上限）

## 6. Quality & CI
- [x] 6.1 单元测试覆盖核心：状态机、API 参数校验、执行适配层（mock Executor）
- [x] 6.2 CI 自动跑测试与 lint（无交互）

