# Project Context

## Purpose
`kdeploy` 是一个 Ruby Gem 形式的轻量级无代理部署工具：使用 Ruby DSL 定义主机/角色/任务，通过 SSH/SCP 在多台服务器上并发执行命令、上传文件/模板、同步目录，并以彩色输出展示结果。

## Tech Stack
- Ruby (Gem)
- CLI: Thor
- SSH/SCP: net-ssh / net-scp
- Concurrency: concurrent-ruby
- Output: pastel / tty-box / tty-table
- Testing: RSpec
- Lint: RuboCop

## Project Conventions

### Code Style
- Ruby 文件使用 `# frozen_string_literal: true`
- 代码质量检查使用 RuboCop（本项目禁用 Metrics 族，保留风格/正确性类检查）
- 公共 API / 复杂逻辑优先补充中文注释（遵循仓库规则）

### Architecture Patterns
- DSL：`Kdeploy::DSL` 负责 host/role/task/steps 的定义与收集
- CLI：`Kdeploy::CLI` 负责解析参数、加载 task 文件、调度执行与输出
- Runner：并发执行（线程池），每 host 运行 task steps
- Executor：SSH/SCP 与目录同步的底层实现（支持 sudo / base_dir 相对路径解析）

### Testing Strategy
- 单元测试优先（避免真实 SSH 连接），通过 stub/double 覆盖关键行为（dry-run 不触发 Runner、sync 过滤逻辑等）
- 关键路径（CLI/DSL/同步过滤）必须有测试覆盖

### Git Workflow
- Commit message 使用 Conventional Commits
- PR / push 自动跑 CI（RSpec + RuboCop），发布仅在 push main 且测试通过后进行

## Domain Context
- “任务文件（deploy.rb）” 是用户编写的 Ruby DSL 脚本；可通过 `include_tasks` 模块化拆分为多个 tasks 文件
- 任务步骤类型：`run`（远程命令）、`upload`、`upload_template`、`sync`

## Important Constraints
- 所有脚本与测试必须支持 CI/CD 的全自动、无交互运行
- 避免在仓库中提交敏感信息（密码、token、私钥等）

## External Dependencies
- RubyGems（发布）
