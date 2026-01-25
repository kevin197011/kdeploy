# Change: add-retry-support

## Why
在真实网络环境中，SSH/SCP 操作偶尔会因抖动、瞬时超时、连接复位等原因失败。当前 `kdeploy` 一旦某一步失败就直接标记该 host 失败并结束该 host 的执行，这对短暂故障不够“韧性”。

## What Changes
- 新增可选重试能力（默认不重试，保持现有行为不变）：
  - CLI：`--retries N`（默认 0）、`--retry-delay SECONDS`（默认 1）
  - 配置：`.kdeploy.yml` 支持 `retries` 与 `retry_delay`
  - 优先级：CLI option > `.kdeploy.yml` > 代码默认
- 重试范围：
  - `run`（SSH）
  - `upload` / `upload_template` / `sync`（SCP/模板/同步内部上传）
  - 仅对可恢复类错误进行重试（SSH/SCP/Template 相关错误），避免对配置错误等进行无意义重试
- 文档与 help 更新，补充使用示例
- 增加单测覆盖：发生失败后按次数重试，最终成功/最终失败行为正确

## Non-Goals
- 不引入复杂的退避算法（先线性 delay 即可）。
- 不引入“继续执行剩余步骤”的 continue-on-error（后续可另起 change）。

## Impact
- Affected code:
  - `lib/kdeploy/configuration.rb`
  - `lib/kdeploy/cli.rb`
  - `lib/kdeploy/runner.rb`
  - `lib/kdeploy/command_executor.rb`
  - `lib/kdeploy/help_formatter.rb`
  - `README.md` / `README_EN.md`
  - `spec/*`

