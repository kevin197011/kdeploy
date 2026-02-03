# Change: Harden Execution Reliability and Web Console Security

## Why
目前并发执行、超时控制、错误可观察性与 Web Console 安全存在潜在风险，生产使用时可能导致任务阻塞、排查困难或未授权访问。需要一次性收敛关键风险并给出可配置、默认安全的行为。

## What Changes
- **Execution**: 增加并发任务超时控制与更安全的结果收集方式，避免单 host 阻塞全局结果。
- **Retries**: 支持对非零退出的命令进行可选重试策略（可配置）。
- **Errors/Observability**: 扩展结构化输出，保留 exit status、command 等关键字段，改进报错定位。
- **Web Console Security**: 强制要求 `JOB_CONSOLE_TOKEN`，默认拒绝无 token 访问；限制可执行 task 文件路径。

## Impact
- Affected specs: execution-orchestration, reliability, cli-output, machine-output, job-console, job-api
- Affected code:
  - lib/kdeploy/runner.rb
  - lib/kdeploy/command_executor.rb
  - lib/kdeploy/cli.rb
  - lib/kdeploy/output_formatter.rb
  - web/lib/auth.rb
  - web/lib/execution_adapter.rb
  - web/app/app.rb
  - web/README.md
