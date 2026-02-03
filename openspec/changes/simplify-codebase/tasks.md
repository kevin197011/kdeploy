## 1. 移除 CommandGrouper
- [x] 1.1 修改 Runner：直接遍历 commands 执行，移除 CommandGrouper.group 与 task_description/show_task_header 调用
- [x] 1.2 删除 `lib/kdeploy/command_grouper.rb`
- [x] 1.3 更新 `lib/kdeploy.rb` 移除 CommandGrouper 的 require

## 2. 简化 OutputFormatter
- [x] 2.1 移除 `step_already_shown?` 与 `mark_step_as_shown`
- [x] 2.2 修改 `format_upload_steps`、`format_template_steps`、`format_sync_steps`、`format_run_steps`：不再传入/使用 `shown` 参数，按序输出所有步骤

## 3. 简化 Runner
- [x] 3.1 移除 `[Progress: X/Y hosts completed]` 输出
- [x] 3.2 移除 `[Step X/Y]` 输出（execute_command_group 内）
- [x] 3.3 移除对 CommandGrouper 的依赖后，确保 execute_grouped_commands 改为直接 iterate commands

## 4. 清理 CommandExecutor
- [x] 4.1 删除 `format_command_by_type`、`format_run_command` 方法
- [x] 4.2 删除或简化 `show_command_header` 及其调用（若已空实现可保留空壳或移除调用）

## 5. 移除无关资源
- [x] 5.1 删除 `.shared/` 目录（确认无其他引用后）
- [x] 5.2 如有 `.gitignore` 或 CI 引用，一并清理

## 6. 验证
- [x] 6.1 运行 `bundle exec rspec` 确保通过
- [x] 6.2 运行 `bundle exec rubocop` 确保通过
- [x] 6.3 执行 `kdeploy execute sample/deploy.rb deploy_web --dry-run` 确认输出正常
