# Design: simplify-codebase

## Context

kdeploy 经多轮迭代后，部分内部逻辑变得冗余：CommandGrouper 对命令分组后每组多为单条命令；OutputFormatter 的步骤去重逻辑为边缘场景服务；Runner 在任务执行中打印进度；CommandExecutor 存在从未调用的格式化方法。本设计在保持用户可见行为不变的前提下，移除这些累赘逻辑。

## Goals / Non-Goals

**Goals:**
- 移除 CommandGrouper，Runner 直接遍历 commands
- 移除 OutputFormatter 步骤去重（step_already_shown/mark_step_as_shown）
- 移除 Runner 执行中进度输出（Progress、Step X/Y）
- 移除 CommandExecutor 死代码（format_command_by_type、format_run_command）
- 移除 `.shared/ui-ux-pro-max` 无关资源

**Non-Goals:**
- 不删除 CLI 选项或 JSON/dry-run 等已交付功能
- 不修改 Web Job Console、sample、文档结构

## Decisions

### 1. 移除 CommandGrouper

- **现状**：`CommandGrouper.group(commands)` 按 `type_source` 或 `type_command` 生成唯一 key，每组通常仅一条命令。
- **决策**：Runner 直接 `commands.each` 执行，不再分组。`show_task_header(task_desc)` 已为空实现，一并移除调用。
- **影响**：Runner 逻辑更直观；需更新 `lib/kdeploy.rb` 的 require。

### 2. 移除 OutputFormatter 步骤去重

- **现状**：`step_already_shown?`/`mark_step_as_shown` 用 `[command, type].hash` 去重，避免同一命令重复显示。
- **决策**：移除去重，按序输出所有步骤。同一任务内重复步骤极少，去重复杂度大于收益。
- **影响**：若任务含重复 `run "echo x"`，将显示两次；可接受。

### 3. 移除 Runner 进度输出

- **现状**：`[Progress: X/Y hosts completed]` 与 `[Step X/Y]` 在执行中打印。
- **决策**：删除上述输出。最终结果（host 状态、步骤列表、summary）已足够。
- **影响**：执行过程更安静；对自动化脚本无影响。

### 4. 移除 CommandExecutor 死代码

- **现状**：`show_command_header` 为空实现；`format_command_by_type`、`format_run_command` 从未被调用。
- **决策**：删除 `format_command_by_type`、`format_run_command`；保留 `show_command_header` 空实现或删除其调用点（若无其他调用者可删除方法）。
- **影响**：减少死代码，无行为变化。

### 5. 移除 .shared 目录

- **现状**：`.shared/ui-ux-pro-max` 含设计系统 CSV 与 Python 脚本，与 kdeploy 无关。
- **决策**：删除整个 `.shared` 目录。若 `.gitignore` 或 CI 有引用，一并清理。
- **影响**：仓库更干净；需确认无其他项目依赖此路径。

## Risks / Trade-offs

- **步骤去重移除**：极少数含大量重复步骤的任务可能输出变长；可接受。
- **进度输出移除**：习惯看进度者可能不适应；最终 summary 仍可用。
