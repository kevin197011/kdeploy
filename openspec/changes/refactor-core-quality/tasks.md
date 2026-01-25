## 1. OpenSpec 基础
- [x] 1.1 为 `task-definition` 与 `task-execution` 编写 spec deltas（至少每条 Requirement 1 个 Scenario）
- [x] 1.2 `openspec validate refactor-core-quality --strict` 通过

## 2. DSL 与可测试性对齐
- [x] 2.1 梳理并固定 DSL 的“稳定读取接口”（hosts/roles/tasks 访问方式），并在 spec 中明确
- [x] 2.2 修复现有 `spec/kdeploy_spec.rb` 与真实 DSL 的不一致
- [x] 2.3 补充 DSL 关键行为测试：`include_tasks`、`assign_task`、host/role/task 解析

## 3. CLI 一致性与文档
- [x] 3.1 统一 `--parallel` 默认值来源与展示（CLI 默认、配置默认、help/README 文案一致）
- [x] 3.2 补齐 `--debug` 选项在 help/README 中的说明
- [x] 3.3 补充 CLI 行为测试：任务选择（单任务/全部任务）、`--limit`、`--dry-run` 不执行网络操作

## 4. 执行与输出可靠性
- [x] 4.1 输出：`--debug` 时打印 stdout/stderr，stderr 颜色语义正确；非 debug 保持简洁
- [x] 4.2 错误：失败时包含 host/task/command 上下文；保留原始异常信息用于定位
- [x] 4.3 同步：`sync` 的 ignore/exclude/delete 行为可预测且有测试覆盖

## 5. CI 质量门禁（最小集）
- [x] 5.1 在 GitHub Actions 中增加/调整 job：`bundle exec rspec` 与 `bundle exec rubocop`
- [x] 5.2 确保 CI 全自动、无交互（符合项目规范）

