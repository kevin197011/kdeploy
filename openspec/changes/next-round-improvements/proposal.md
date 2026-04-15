# Change: Next Round Improvements (Web Console, Execution Reliability, Sync Performance)

## Why
用户希望继续推进 Web Console、执行引擎可靠性与同步性能的改进。本提案统一规划这些能力，确保变更边界明确、具备测试覆盖并保持默认行为兼容。

## What Changes
- **Web Console**: 增强运行历史筛选与 Run 详情可读性（结构化输出展示）。
- **Execution Reliability**: 支持 step 级超时与更细粒度的重试策略。
- **Sync Performance**: 改进 rsync/fast sync 统计与并行度控制（可选、默认不变）。

## Impact
- Affected specs: job-console, cli-output, machine-output, task-execution, reliability, sync
- Affected code:
  - web/app/app.rb
  - web/views/*
  - web/lib/models.rb
  - web/lib/execution_adapter.rb
  - lib/kdeploy/runner.rb
  - lib/kdeploy/command_executor.rb
  - lib/kdeploy/executor.rb
  - lib/kdeploy/output_formatter.rb
