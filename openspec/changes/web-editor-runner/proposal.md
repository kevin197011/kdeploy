# Change: Web Editor Runner (CodeMirror, File-backed, Async Output)

## Why
用户需要一个单页 Web 控制台：登录后直接编辑 `deploy.rb`，支持语法高亮，点击运行后异步执行并流式显示输出。相比多页面 Job/Run 管理，新的体验更直接、轻量。

## What Changes
- **UI**: 单页编辑器（CodeMirror 6）+ 运行按钮 + 输出弹窗（流式）。
- **Storage**: 编辑内容保存到 `JOB_CONSOLE_TASK_BASE_DIR` 下指定文件。
- **Execution**: 异步运行，前端轮询/流式拉取输出。

## Impact
- Affected specs: job-console, job-api, execution-orchestration, cli-output
- Affected code:
  - web/app/app.rb
  - web/views/*
  - web/lib/orchestrator.rb
  - web/lib/execution_adapter.rb
  - web/README.md
