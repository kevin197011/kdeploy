# Change: simplify-codebase

## Why

项目经过多轮迭代后累积了部分累赘逻辑与未使用功能：CommandGrouper 分组后每组通常仅含单条命令、OutputFormatter 的步骤去重逻辑增加复杂度却收益有限、Runner 的进度输出增加噪音、CommandExecutor 存在未调用的格式化方法、`.shared/ui-ux-pro-max` 与 kdeploy 无关。简化后能降低维护成本、减少认知负担，并保持核心功能不变。

## What Changes

- **移除 CommandGrouper**：Runner 直接遍历 commands 执行，不再按组包装。分组逻辑对单命令组无实质收益。
- **移除 OutputFormatter 步骤去重**：删除 `step_already_shown`/`mark_step_as_shown`，直接按序输出所有步骤。同一任务内重复步骤罕见，去重逻辑复杂度大于收益。
- **移除 Runner 执行中进度输出**：删除 `[Progress: X/Y hosts completed]` 与 `[Step X/Y]`，减少噪音。最终结果展示已足够。
- **移除 CommandExecutor 死代码**：删除未调用的 `format_command_by_type`、`format_run_command`（`show_command_header` 已为空实现，可一并简化）。
- **移除无关资源**：删除 `.shared/ui-ux-pro-max` 目录（与 kdeploy 无关的设计系统数据）。
- **可选简化**：DSL 中 `hosts`/`tasks`/`roles` 与 `kdeploy_hosts`/`kdeploy_tasks`/`kdeploy_roles` 的别名可保留其一；Configuration 的 `parse_verify_host_key` 可收紧支持的取值。

### 非目标（本次不变）

- 不修改 CLI 对外选项（`--format`、`--dry-run`、`--debug` 等）与行为。
- 不修改 Web Job Console 与 sample 任务逻辑。
- 不删除 retry、JSON 输出、资源 DSL 等已交付功能。

## Impact

- **Affected specs**:
  - `task-execution`（MODIFIED：Runner 执行流程简化）
  - `cli-output`（MODIFIED：输出格式化逻辑简化）
- **Affected code**:
  - `lib/kdeploy/runner.rb`（移除 CommandGrouper 调用、进度输出）
  - `lib/kdeploy/command_grouper.rb`（**REMOVED**）
  - `lib/kdeploy/output_formatter.rb`（移除步骤去重）
  - `lib/kdeploy/command_executor.rb`（移除死代码）
  - `lib/kdeploy.rb`（移除 CommandGrouper require）
  - `.shared/`（**REMOVED**，若确认无其他引用）
- **Compatibility**:
  - 用户可见行为保持不变（输出格式、CLI 选项、任务执行顺序与结果）。仅内部实现简化。
