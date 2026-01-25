## 1. Spec
- [x] 1.1 为 `cli-output` 与 `machine-output` 编写 spec deltas
- [x] 1.2 `openspec validate add-automation-output --strict` 通过

## 2. Implementation
- [x] 2.1 新增 CLI 选项：`--no-banner`、`--format (text|json)`
- [x] 2.2 `--format json`：输出结构包含 task/host/steps/duration/status/error
- [x] 2.3 `--dry-run --format json`：输出计划步骤且不创建 Runner/不触发网络
- [x] 2.4 README/help 更新

## 3. Tests
- [x] 3.1 `--no-banner` 不输出 banner
- [x] 3.2 `--format json` 输出可被 JSON.parse
- [x] 3.3 `--dry-run` 不触发 Runner（现有测试保持）
