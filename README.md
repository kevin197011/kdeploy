# Kdeploy

```
          _            _
  /\ /\__| | ___ _ __ | | ___  _   _
 / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
/ __ \ (_| |  __/ |_) | | (_) | |_| |
\/  \/\__,_|\___| .__/|_|\___/ \__, |
                |_|            |___/

  ⚡ Lightweight Agentless Deployment Tool
  🚀 Deploy with confidence, scale with ease
```

[![Gem Version](https://badge.fury.io/rb/kdeploy.svg)](https://rubygems.org/gems/kdeploy)
[![CI](https://github.com/kevin197011/kdeploy/actions/workflows/ci.yml/badge.svg)](https://github.com/kevin197011/kdeploy/actions/workflows/ci.yml)

Kdeploy 是一个现代化的轻量级 agentless 运维部署工具，类似于 Chef、Puppet 和 Ansible。它采用优雅的 Ruby DSL 语法，支持并发执行、统计分析和完整的部署生命周期管理。

## ✨ 特性

- 🚀 **轻量级**: 无需在目标服务器安装 agent，基于 SSH 连接
- 🎨 **现代界面**: 美观的 ASCII 艺术字和彩色输出界面
- 🔧 **DSL 语法**: 简洁优雅的 Ruby DSL 配置语法
- ⚡ **并发执行**: 支持多主机并发操作和智能并发控制
- 🛠️ **批量操作**: 高效的批量 Shell 命令执行
- 🔒 **安全连接**: 基于 SSH 的安全连接，支持密钥认证
- 📝 **实时输出**: 命令执行结果实时显示，包含详细执行时间统计
- 🎯 **角色管理**: 灵活的基于角色的主机分组管理
- 📋 **Inventory 管理**: 强大的 YAML 格式主机清单，支持群组和变量继承
- 🧩 **Heredoc 语法**: 支持多行 Shell 脚本的 heredoc 语法
- 🎨 **ERB 模板**: 内置 ERB 模板引擎，支持动态配置文件生成
- 🏷️ **变量替换**: 支持 `{{variable}}` 和 `${variable}` 双重模板语法
- 🖥️ **混合执行**: 支持本地命令执行和混合部署场景
- 📊 **统计分析**: 自动收集部署统计，支持性能分析和趋势监控
- 🔄 **脚本库**: 丰富的预制脚本模板，覆盖完整部署生命周期
- 🧩 **模块化架构**: 支持脚本模块化组织，可复用通用任务组件
- 🛡️ **错误恢复**: 智能错误处理和自动重试机制

## 📦 安装

将以下内容添加到您的 Gemfile：

```ruby
gem 'kdeploy'
```

然后执行：

```bash
$ bundle install
```

或者直接安装：

```bash
$ gem install kdeploy
```

## 🚀 快速开始

### 1. 初始化项目

```bash
$ kdeploy init myapp
$ cd myapp
```

kdeploy 会自动创建完整的项目结构，包含多个实用脚本范例：

```
myapp/
├── deploy.rb                    # 主部署脚本
├── inventory.yml               # 主机清单配置
├── config/                     # 配置文件目录
│   └── kdeploy.yml            # 全局配置文件
├── scripts/                   # 🆕 完整脚本库
│   ├── common_tasks.rb        # 🆕 通用任务模块(可复用)
│   ├── setup.rb              # 服务器初始化
│   ├── database.rb            # 数据库管理
│   ├── backup.rb              # 备份操作
│   ├── monitoring.rb          # 监控和健康检查
│   ├── rollback.rb            # 回滚操作
│   └── cleanup.rb             # 清理维护
└── templates/                 # ERB模板文件
    ├── nginx.conf.erb         # Nginx配置模板
    ├── app.service.erb        # Systemd服务模板
    ├── deploy.sh.erb          # 部署脚本模板
    └── backup.sh.erb          # 备份脚本模板
```

### 2. 配置服务器清单

编辑 `inventory.yml` 配置主机清单：

```yaml
# 全局变量
vars:
  application: myapp
  version: 1.0.0
  deploy_to: /opt/myapp
  environment: production

# 主机群组
groups:
  webservers:
    hosts:
      - web1.example.com
      - web2.example.com
    vars:
      nginx_port: 80
      app_port: 3000

  databases:
    hosts:
      - db1.example.com
    vars:
      postgres_port: 5432
      backup_enabled: true

  production:
    children:
      - webservers
      - databases
    vars:
      environment: production

# 主机详细配置
hosts:
  web1.example.com:
    user: deploy
    port: 22
    roles: [web, app]
    ssh:
      key_file: ~/.ssh/id_rsa
      verify_host_key: false
    vars:
      server_id: 1

  web2.example.com:
    user: deploy
    port: 22
    roles: [web, app]
    ssh:
      key_file: ~/.ssh/id_rsa
      verify_host_key: false
    vars:
      server_id: 2

  db1.example.com:
    user: deploy
    port: 22
    roles: [database]
    ssh:
      key_file: ~/.ssh/id_rsa
      verify_host_key: false
    vars:
      server_id: 3
      master: true
```

### 3. 使用预制脚本

kdeploy 提供了完整的脚本库，覆盖部署的各个阶段：

#### 🔧 服务器初始化
```bash
# 首次部署前执行，安装依赖和配置环境
$ kdeploy deploy scripts/setup.rb
```

#### 💾 数据库管理
```bash
# 数据库相关操作
$ kdeploy deploy scripts/database.rb  # 创建数据库、迁移、备份
```

#### 🚀 应用部署
```bash
# 主要应用部署
$ kdeploy deploy deploy.rb
```

#### 📊 健康监控
```bash
# 系统和应用健康检查
$ kdeploy deploy scripts/monitoring.rb
```

#### 💾 备份操作
```bash
# 应用和数据备份
$ kdeploy deploy scripts/backup.rb
```

#### 🔙 回滚操作
```bash
# 紧急回滚和恢复
$ kdeploy deploy scripts/rollback.rb
```

#### 🧹 清理维护
```bash
# 系统清理和维护
$ kdeploy deploy scripts/cleanup.rb
```

#### 🧩 通用任务模块
```bash
# 使用通用任务模块进行基础设置
$ kdeploy deploy scripts/common_tasks.rb --task setup_environment

# 执行安全加固
$ kdeploy deploy scripts/common_tasks.rb --task security_hardening

# 在主脚本中引入模块化任务
# deploy.rb 中自动包含: include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')
```

### 4. 部署工作流示例

```bash
# 1. 验证配置
$ kdeploy validate deploy.rb

# 2. 首次服务器设置
$ kdeploy deploy scripts/setup.rb

# 3. 设置数据库
$ kdeploy deploy scripts/database.rb

# 4. 执行应用部署
$ kdeploy deploy deploy.rb --verbose

# 5. 健康检查
$ kdeploy deploy scripts/monitoring.rb

# 6. 查看统计信息
$ kdeploy stats summary
```

## 📊 统计和监控功能

Kdeploy 提供了强大的内置统计功能，自动跟踪所有部署活动：

### 📈 自动收集的统计数据

- ✅ **成功/失败统计**: 部署、任务和命令级别的成功失败率
- ⏱️ **性能指标**: 详细的执行时间和性能数据
- 📅 **历史趋势**: 按日期分组的性能趋势分析
- 🎯 **失败分析**: 识别最常失败的任务和错误模式
- 🌍 **全局统计**: 跨会话的累计统计数据

### 🔍 统计命令

```bash
# 查看统计概要
$ kdeploy stats summary

# 查看部署统计
$ kdeploy stats deployments

# 查看任务统计
$ kdeploy stats tasks

# 查看失败统计
$ kdeploy stats failures

# 查看性能趋势
$ kdeploy stats trends

# 查看全局统计
$ kdeploy stats global

# 导出统计数据
$ kdeploy stats export --export monthly_report.json

# 清空统计数据
$ kdeploy stats clear

# 指定时间范围（天数）
$ kdeploy stats summary --days 7

# JSON格式输出
$ kdeploy stats tasks --format json
```

### 📊 统计输出示例

```bash
$ kdeploy stats summary

📊 Kdeploy Statistics Summary (Last 30 days)
=====================================================

📦 Deployment Summary:
  Total Deployments: 15
  Successful: 13 (86.7%)
  Failed: 2 (13.3%)
  Average Duration: 45.2s

🔧 Task Summary:
  Total Tasks: 89
  Successful: 84 (94.4%)
  Failed: 5 (5.6%)
  Average Duration: 12.8s

🌍 Global Statistics:
  Total Deployments: 156
  Session Duration: 2h 34m
  Most Active Day: 2025-06-28 (8 deployments)
```

## 🔧 模块化脚本组织

Kdeploy 支持模块化脚本组织，让您可以将复杂的部署逻辑拆分成可重用的组件。

### 📋 模块化引入语法

在 `deploy.rb` 主脚本中，您可以引入其他脚本文件：

```ruby
# 引入通用任务模块（如果文件存在）
include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')

# 引入项目特定任务
include 'scripts/myapp_tasks.rb' if File.exist?('scripts/myapp_tasks.rb')

# 引入环境特定任务
include 'scripts/production_tasks.rb' if File.exist?('scripts/production_tasks.rb')
include 'scripts/staging_tasks.rb' if File.exist?('scripts/staging_tasks.rb')
```

### 🏗️ common_tasks.rb - 通用任务库

Kdeploy 自动生成 `scripts/common_tasks.rb` 文件，包含常用的基础设施任务：

#### 环境设置任务
```ruby
# 基础环境设置
task 'setup_environment', on: :all do
  run 'sudo timedatectl set-timezone UTC', ignore_errors: true
  run 'sudo apt-get update -qq', ignore_errors: true
  run 'sudo apt-get install -y -qq htop curl wget vim git unzip', ignore_errors: true
end

# SSL证书配置
task 'setup_ssl', on: :webservers do
  run 'sudo apt-get install -y certbot python3-certbot-nginx', ignore_errors: true
  run 'sudo certbot --nginx --dry-run -d {{hostname}}', ignore_errors: true
end

# 日志轮转配置
task 'setup_log_rotation', on: :all do
  run <<~LOGROTATE
    sudo tee /etc/logrotate.d/{{application}} > /dev/null << 'EOF'
    {{deploy_to}}/shared/logs/*.log {
        daily
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 644 {{user}} {{user}}
    }
    EOF
  LOGROTATE
end
```

#### 安全加固任务
```ruby
# 系统安全强化
task 'security_hardening', on: :all do
  # 禁用root登录
  run 'sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config', ignore_errors: true

  # 配置防火墙
  run 'sudo ufw --force reset', ignore_errors: true
  run 'sudo ufw default deny incoming', ignore_errors: true
  run 'sudo ufw default allow outgoing', ignore_errors: true
  run 'sudo ufw allow ssh', ignore_errors: true
  run 'sudo ufw allow {{nginx_port || 80}}', ignore_errors: true
  run 'sudo ufw --force enable', ignore_errors: true

  # 安装fail2ban
  run 'sudo apt-get install -y fail2ban', ignore_errors: true
  run 'sudo systemctl enable fail2ban', ignore_errors: true
end
```

#### 应急处理任务
```ruby
# 紧急停止所有服务
task 'emergency_stop', on: :all do
  run 'echo "🚨 Emergency stop initiated on {{hostname}}"'
  run 'sudo systemctl stop {{application}}', ignore_errors: true
  run 'sudo systemctl stop nginx', ignore_errors: true
end

# 紧急启动所有服务
task 'emergency_start', on: :all do
  run 'echo "🚨 Emergency start initiated on {{hostname}}"'
  run 'sudo systemctl start nginx', ignore_errors: true
  run 'sudo systemctl start {{application}}', ignore_errors: true
end
```

### 🔗 使用模块化任务

#### 在主脚本中调用模块化任务

```ruby
# deploy.rb - 主部署脚本
include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')

# 完整部署工作流，使用通用任务
task 'full_setup_with_common_tasks' do
  run_task 'pre_deploy_checks'       # 来自 common_tasks.rb
  run_task 'setup_environment'       # 来自 common_tasks.rb
  run_task 'security_hardening'      # 来自 common_tasks.rb
  run_task 'performance_tuning'      # 来自 common_tasks.rb
  run_task 'deploy'                  # 来自当前文件
  run_task 'verify_deployment'       # 来自 common_tasks.rb
end

# 应急处理演示
task 'emergency_procedures_demo' do
  # 这些任务来自 common_tasks.rb:
  # run_task 'emergency_stop'         # 停止所有服务
  # run_task 'emergency_start'        # 启动所有服务
  # run_task 'health_check_all'       # 综合健康检查
end
```

#### 单独执行模块化任务

```bash
# 执行通用环境设置
kdeploy deploy scripts/common_tasks.rb --task setup_environment

# 执行安全加固
kdeploy deploy scripts/common_tasks.rb --task security_hardening

# 应急操作
kdeploy deploy scripts/common_tasks.rb --task emergency_stop
kdeploy deploy scripts/common_tasks.rb --task emergency_start

# 部署验证
kdeploy deploy scripts/common_tasks.rb --task verify_deployment
```

### 📁 项目特定任务模块

创建项目特定的任务文件：

```ruby
# scripts/myapp_tasks.rb
task 'install_nodejs', on: :webservers do
  run 'curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -'
  run 'sudo apt-get install -y nodejs'
  run 'node --version && npm --version'
end

task 'build_frontend', on: :webservers do
  run 'cd {{deploy_to}} && npm install'
  run 'cd {{deploy_to}} && npm run build'
end

task 'deploy_myapp' do
  run_task 'setup_environment'    # 来自 common_tasks.rb
  run_task 'install_nodejs'       # 来自当前文件
  run_task 'build_frontend'       # 来自当前文件
  run_task 'verify_deployment'    # 来自 common_tasks.rb
end
```

### 🌍 环境特定任务

```ruby
# scripts/production_tasks.rb
task 'production_ssl_setup', on: :webservers do
  run 'sudo certbot --nginx -d {{hostname}} --non-interactive --agree-tos --email admin@{{hostname}}'
end

task 'production_monitoring', on: :all do
  run 'sudo apt-get install -y datadog-agent'
  run 'sudo systemctl enable datadog-agent'
end

# scripts/staging_tasks.rb
task 'staging_debug_mode', on: :webservers do
  run 'export DEBUG=true'
  run 'export LOG_LEVEL=debug'
end
```

### 💡 模块化最佳实践

1. **按功能分组**: 将相关任务放在同一个模块中
2. **条件引入**: 使用 `if File.exist?` 确保文件存在性检查
3. **任务命名**: 使用清晰的任务名称，避免冲突
4. **文档注释**: 为每个模块添加详细的使用说明
5. **测试验证**: 使用 `kdeploy validate` 验证脚本语法

### 🚀 模块化工作流示例

```bash
# 1. 完整的生产环境部署
kdeploy deploy deploy.rb --task full_setup_with_common_tasks

# 2. 分步骤执行
kdeploy deploy scripts/common_tasks.rb --task setup_environment
kdeploy deploy scripts/common_tasks.rb --task security_hardening
kdeploy deploy deploy.rb --task deploy
kdeploy deploy scripts/common_tasks.rb --task verify_deployment

# 3. 环境特定配置
kdeploy deploy scripts/production_tasks.rb --task production_ssl_setup

# 4. 应急处理
kdeploy deploy scripts/common_tasks.rb --task emergency_stop
kdeploy deploy scripts/common_tasks.rb --task emergency_start
```

这种模块化组织方式让您可以：
- 🔄 **复用代码**: 在多个项目间共享通用任务
- 🎯 **专注职责**: 每个模块专注特定功能领域
- 🔧 **灵活组合**: 根据需要灵活组合不同模块
- 📝 **易于维护**: 模块化结构便于维护和测试

## 🛠️ 脚本库详解

### setup.rb - 服务器初始化脚本

完整的服务器环境准备：

```ruby
# 安装系统依赖
task 'install_dependencies', on: :all do
  run 'sudo apt-get update'
  run 'sudo apt-get install -y curl git build-essential'
  run 'sudo apt-get install -y nginx postgresql redis-server'
end

# 创建应用用户
task 'setup_user', on: :all do
  run 'sudo useradd -m -s /bin/bash {{user}}', allow_failure: true
  run 'sudo mkdir -p /home/{{user}}/.ssh'
  run 'sudo cp ~/.ssh/authorized_keys /home/{{user}}/.ssh/'
  run 'sudo chown -R {{user}}:{{user}} /home/{{user}}/.ssh'
end

# 配置防火墙
task 'setup_firewall', on: :all do
  run 'sudo ufw allow ssh'
  run 'sudo ufw allow {{nginx_port || 80}}'
  run 'sudo ufw --force enable'
end
```

### database.rb - 数据库管理脚本

数据库生命周期管理：

```ruby
# 创建数据库
task 'create_database', on: :databases do
  run 'sudo -u postgres createdb {{application}}_{{environment}}', allow_failure: true
  run 'sudo -u postgres createuser {{application}}_user', allow_failure: true
  run %(sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE {{application}}_{{environment}} TO {{application}}_user;")
end

# 数据库迁移
task 'migrate', on: :databases do
  run 'cd {{deploy_to}} && npm run migrate'
end

# 数据库备份
task 'backup', on: :databases do
  run 'mkdir -p /backup/{{application}}'
  run 'pg_dump {{application}}_{{environment}} > /backup/{{application}}/backup_$(date +%Y%m%d_%H%M%S).sql'
end
```

### monitoring.rb - 监控健康检查脚本

全面的系统和应用监控：

```ruby
# 系统健康检查
task 'system_health', on: :all do
  run 'echo "=== System Health for {{hostname}} ==="'
  run 'uptime'
  run 'df -h'
  run 'free -h'
  run 'ps aux --sort=-%cpu | head -10'
end

# 应用健康检查
task 'app_health', on: :webservers do
  run 'systemctl status {{application}}', allow_failure: true
  run 'curl -f http://localhost:{{app_port}}/health || echo "Health check failed"',
      timeout: 10, allow_failure: true
end

# 性能监控
task 'performance_check', on: :webservers do
  run 'curl -w "Connect: %{time_connect}s, Total: %{time_total}s\\n" -s -o /dev/null http://localhost:{{app_port}}/',
      timeout: 15, allow_failure: true
end
```

### rollback.rb - 回滚操作脚本

灵活的回滚和恢复机制：

```ruby
# 快速回滚到上一版本
task 'rollback', on: :webservers do
  run 'cd {{deploy_to}} && git log --oneline -5'
  run 'cd {{deploy_to}} && git reset --hard HEAD~1'
  run 'sudo systemctl restart {{application}}'
end

# 回滚到指定版本
task 'rollback_to_commit', on: :webservers do |hosts, commit_hash|
  commit_hash ||= ENV['COMMIT_HASH']
  raise 'Please specify COMMIT_HASH environment variable' unless commit_hash

  run "cd {{deploy_to}} && git reset --hard #{commit_hash}"
  run 'sudo systemctl restart {{application}}'
end

# 维护模式
task 'maintenance_on', on: :webservers do
  run 'echo "maintenance" > {{deploy_to}}/public/maintenance.txt'
  run 'sudo nginx -s reload'
end
```

## 🎨 模板系统

### ERB 模板示例

`templates/nginx.conf.erb`:
```erb
# Nginx configuration for <%= application %>
server {
    listen <%= nginx_port || 80 %>;
    server_name <%= hostname %>;
    root <%= deploy_to %>/public;

    location / {
        try_files $uri $uri/ @app;
    }

    location @app {
        proxy_pass http://127.0.0.1:<%= app_port || 3000 %>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Static files cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/<%= application %>_access.log;
    error_log /var/log/nginx/<%= application %>_error.log;
}
```

### 使用模板

```ruby
task 'configure_nginx', on: :webservers do
  upload_template 'nginx.conf', '/etc/nginx/sites-available/{{application}}'
  run 'sudo ln -sf /etc/nginx/sites-available/{{application}} /etc/nginx/sites-enabled/'
  run 'sudo nginx -t && sudo systemctl reload nginx'
end
```

## 🖥️ 命令行接口

### 主要命令

```bash
# 项目管理
kdeploy init [PROJECT_NAME]           # 初始化新项目
kdeploy validate SCRIPT               # 验证部署脚本
kdeploy config                        # 显示当前配置

# 部署执行
kdeploy deploy SCRIPT                 # 执行部署脚本
kdeploy execute SCRIPT                # 执行脚本（别名）

# 统计分析
kdeploy stats summary                 # 统计概要
kdeploy stats deployments            # 部署统计
kdeploy stats tasks                   # 任务统计
kdeploy stats failures               # 失败统计
kdeploy stats trends                  # 性能趋势
kdeploy stats global                  # 全局统计
kdeploy stats export                  # 导出数据
kdeploy stats clear                   # 清空统计

# 帮助信息
kdeploy version                       # 显示版本
kdeploy help                          # 显示帮助
kdeploy help [COMMAND]                # 特定命令帮助
```

### 命令选项

```bash
# 配置选项
-c, --config FILE                     # 指定配置文件
-i, --inventory FILE                  # 指定inventory文件
-v, --verbose                         # 详细输出模式
-l, --log-file FILE                   # 指定日志文件

# 执行选项
--dry-run                             # 干运行模式
--parallel                            # 并行执行

# 统计选项
--days N                              # 指定天数范围
--format FORMAT                       # 输出格式(table|json)
--export FILE                         # 导出文件路径
```

## 📋 DSL 语法参考

### 基础语法

```ruby
# 加载主机清单
inventory 'inventory.yml'

# 定义变量
set 'application', 'myapp'
set 'version', '1.0.0'

# 定义主机
host '192.168.1.100', user: 'deploy', port: 22

# 定义任务
task 'deploy', on: :webservers do
  run 'echo "Deploying to {{hostname}}"'
end

# 本地命令
local 'echo "Starting deployment"'
```

### 高级语法

```ruby
# 条件执行
task 'conditional_task', on: :all do
  run 'echo "Production server"', only: :production
  run 'echo "Staging server"', except: :production
end

# 错误处理
task 'robust_task', on: :all do
  run 'risky_command',
      allow_failure: true,
      timeout: 30,
      retry_count: 3
end

# 并发控制
task 'parallel_task', on: :all, parallel: true, max_concurrent: 5 do
  run 'long_running_command'
end

# Heredoc 语法
task 'complex_task', on: :all do
  run <<~SCRIPT
    echo "Starting complex deployment"
    cd {{deploy_to}}

    if [ -d .git ]; then
      git pull origin {{branch}}
    else
      git clone {{repo_url}} .
    fi

    npm install --production
    sudo systemctl restart {{application}}
    echo "Deployment completed"
  SCRIPT
end
```

### 变量和模板

```ruby
# 变量使用（两种语法）
run 'echo "Application: {{application}}"'
run 'echo "Version: ${version}"'

# 内置变量
run 'echo "Hostname: {{hostname}}"'
run 'echo "User: {{user}}"'
run 'echo "Port: {{port}}"'

# 模板上传
upload_template 'config.erb', '/etc/myapp/config.yml'
```

## ⚙️ 配置文件

创建 `config/kdeploy.yml`：

```yaml
# 最大并发任务数
max_concurrent_tasks: 10

# 网络超时设置
ssh_timeout: 30
command_timeout: 300

# 重试设置
retry_count: 3
retry_delay: 1

# 日志设置
log_level: info
log_file: kdeploy.log

# 默认设置
default_user: deploy
default_port: 22

# SSH选项
ssh_options:
  verify_host_key: never
  non_interactive: true
  use_agent: true
  forward_agent: false

# 路径设置
inventory_file: inventory.yml
template_dir: templates
```

## 🎯 实际使用案例

### Node.js 应用部署

```ruby
# deploy.rb
inventory 'inventory.yml'

task 'deploy_nodejs', on: :webservers do
  run <<~DEPLOY
    echo "Deploying Node.js app to {{hostname}}"

    # 备份当前版本
    if [ -d "{{deploy_to}}/current" ]; then
      sudo mv {{deploy_to}}/current {{deploy_to}}/backup_$(date +%s)
    fi

    # 创建部署目录
    sudo mkdir -p {{deploy_to}}
    cd {{deploy_to}}

    # 获取最新代码
    if [ -d ".git" ]; then
      git fetch origin
      git reset --hard origin/{{branch}}
    else
      git clone {{repo_url}} .
      git checkout {{branch}}
    fi

    # 安装依赖
    npm install --production

    # 构建应用
    npm run build

    # 重启服务
    sudo systemctl restart {{application}}

    echo "✅ Deployment completed successfully"
  DEPLOY
end

# 健康检查
task 'health_check', on: :webservers do
  run 'curl -f http://localhost:{{app_port}}/health',
      timeout: 30,
      retry_count: 3
end
```

### Docker 应用部署

```ruby
task 'deploy_docker', on: :webservers do
  run <<~DOCKER_DEPLOY
    echo "Deploying Docker application"

    # 拉取最新镜像
    docker pull {{image_name}}:{{version}}

    # 停止旧容器
    docker stop {{application}} || true
    docker rm {{application}} || true

    # 启动新容器
    docker run -d \
      --name {{application}} \
      -p {{app_port}}:3000 \
      -e NODE_ENV={{environment}} \
      {{image_name}}:{{version}}

    # 等待容器启动
    sleep 10

    echo "✅ Docker deployment completed"
  DOCKER_DEPLOY
end
```

### 数据库迁移

```ruby
task 'database_migration', on: :databases do
  run <<~MIGRATION
    echo "Running database migration"

    # 备份数据库
    pg_dump {{application}}_{{environment}} > \
      /backup/pre_migration_$(date +%Y%m%d_%H%M%S).sql

    # 执行迁移
    cd {{deploy_to}}
    NODE_ENV={{environment}} npm run migrate

    echo "✅ Database migration completed"
  MIGRATION
end
```

## 🔧 故障排除

### 常见问题

1. **SSH 连接失败**
   ```bash
   # 检查SSH连接
   ssh -vvv user@hostname

   # 验证密钥
   ssh-add -l
   ```

2. **权限问题**
   ```ruby
   # 使用sudo执行命令
   run 'sudo systemctl restart nginx'

   # 检查文件权限
   run 'ls -la {{deploy_to}}'
   ```

3. **超时问题**
   ```ruby
   # 增加超时时间
   run 'long_command', timeout: 300

   # 或在配置文件中设置
   command_timeout: 600
   ```

### 调试技巧

```bash
# 详细输出模式
kdeploy deploy script.rb --verbose

# 干运行模式
kdeploy deploy script.rb --dry-run

# 查看配置
kdeploy config

# 验证脚本
kdeploy validate script.rb

# 查看日志
tail -f kdeploy.log
```

## 🤝 贡献

我们欢迎社区贡献！请参考以下指南：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 🔗 相关链接

- [项目主页](https://github.com/kevin197011/kdeploy)
- [文档中心](https://github.com/kevin197011/kdeploy/wiki)
- [问题反馈](https://github.com/kevin197011/kdeploy/issues)
- [发布日志](https://github.com/kevin197011/kdeploy/releases)

## 💬 社区支持

- GitHub Issues: [报告问题](https://github.com/kevin197011/kdeploy/issues)
- GitHub Discussions: [社区讨论](https://github.com/kevin197011/kdeploy/discussions)

---

**Kdeploy** - 让部署变得简单而强大 🚀