## 1. Spec
- [x] 1.1 编写 `reliability` spec delta（retries/delay/优先级/适用范围）
- [x] 1.2 `openspec validate add-retry-support --strict` 通过

## 2. Implementation
- [x] 2.1 `Configuration` 增加 `default_retries/default_retry_delay` 并支持 `.kdeploy.yml`
- [x] 2.2 CLI 增加 `--retries/--retry-delay` 并把值透传到 Runner/CommandExecutor
- [x] 2.3 CommandExecutor 对 SSH/SCP/Template 相关错误做重试（默认 0 次）
- [x] 2.4 help/README 更新

## 3. Tests
- [x] 3.1 `run` 重试：前 N 次失败后成功，最终 status=success
- [x] 3.2 `run` 重试：超过次数仍失败，最终 status=failed，错误信息包含上下文

