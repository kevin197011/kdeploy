# Change: Improve Observability, Web Console Usability, and Sync Performance

## Why
目前 CLI/JSON 输出在失败场景信息不一致、模板变量缺失难以定位；Web Console 默认变量未注入执行；目录同步在大项目场景性能受限。需要在不引入破坏性改动的前提下提升可观测性、Web 使用体验与同步性能。

## What Changes
- **Observability**: 统一 JSON 输出结构，CLI 失败输出补充 command/exit status/stderr；模板渲染时提示缺失变量。
- **Web Console**: 支持将 job 默认变量注入任务执行；UI 对执行错误提供更清晰的提示。
- **Sync Performance**: 提供可选的 rsync 同步路径或并行上传机制，默认保持兼容。

## Impact
- Affected specs: cli-output, machine-output, template-engine, job-console, job-api, sync
- Affected code:
  - lib/kdeploy/cli.rb
  - lib/kdeploy/output_formatter.rb
  - lib/kdeploy/template.rb
  - web/lib/execution_adapter.rb
  - web/app/app.rb
  - web/views/*.erb
  - lib/kdeploy/executor.rb (sync)
