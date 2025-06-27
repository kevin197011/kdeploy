# Kdeploy

[![Gem Version](https://badge.fury.io/rb/kdeploy.svg)](https://badge.fury.io/rb/kdeploy)
[![Build Status](https://github.com/kdeploy/kdeploy/workflows/CI/badge.svg)](https://github.com/kdeploy/kdeploy/actions)

Kdeploy 是一个轻量级的 agentless 运维部署工具，类似于 Chef、Puppet 和 Ansible。它采用 Ruby DSL 语法，支持并发执行和批量 Shell 命令执行。

## 特性

- 🚀 **轻量级**: 无需在目标服务器安装 agent
- 🔧 **DSL 语法**: 简洁的 Ruby DSL 配置语法
- ⚡ **并发执行**: 支持多主机并发操作和并发控制
- 🛠️ **批量操作**: 支持批量执行 Shell 命令
- 🔒 **SSH 连接**: 基于 SSH 的安全连接
- 📝 **实时输出**: 命令执行结果实时显示，包含执行时间统计
- 🎯 **角色管理**: 基于角色的主机分组管理
- 📋 **Inventory 管理**: 支持 YAML 格式的主机清单，支持群组和变量管理
- 🧩 **Heredoc 语法**: 支持多行 Shell 脚本的 heredoc 语法
- 🎨 **ERB 模板**: 内置 ERB 模板引擎，支持动态配置文件生成
- 🏷️ **变量替换**: 支持 `{{variable}}` 和 `${variable}` 模板语法
- 🖥️ **本地命令**: 支持本地命令执行和混合部署场景

## 安装

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

## 快速开始

### 1. 初始化项目

```bash
$ kdeploy init myapp
$ cd myapp
```

### 2. 配置主机和任务

编辑 `deploy.rb` 文件：

```ruby
# 设置变量
set 'application', 'myapp'
set 'version', '1.0.0'
set 'deploy_to', '/opt/myapp'

# 定义主机
host '192.168.1.100', user: 'deploy', roles: [:web, :app]
host '192.168.1.101', user: 'deploy', roles: [:db]

# 部署任务
task 'deploy', on: [:web, :app] do
  run 'echo "正在部署 {{application}} v{{version}}..."'

  # 使用 heredoc 语法执行复杂部署逻辑
  run <<~DEPLOYMENT
    echo "Creating deployment directory..."
    sudo mkdir -p {{deploy_to}}
    cd {{deploy_to}}

    echo "Pulling latest code..."
    git pull origin main

    echo "Restarting application..."
    sudo systemctl restart {{application}}

    echo "✅ Deployment completed!"
  DEPLOYMENT
end

# 数据库设置
task 'setup_db', on: :db do
  run 'echo "设置数据库..."'
  run 'sudo systemctl restart postgresql'
end

# 健康检查
task 'health_check' do
  run 'curl -f http://localhost:3000/health || exit 1',
      name: 'health_check',
      timeout: 30
end
```

### 3. 执行部署

```bash
# 验证配置
$ kdeploy validate deploy.rb

# 执行干运行
$ kdeploy deploy deploy.rb --dry-run

# 执行部署（两种方式等价）
$ kdeploy execute deploy.rb
$ kdeploy deploy deploy.rb

# 详细输出模式
$ kdeploy deploy deploy.rb --verbose
```

## 📊 输出示例

Kdeploy 提供丰富的实时输出信息，包括执行状态、耗时统计和命令结果：

```bash
$ kdeploy deploy deploy.rb

🚀 Starting deployment...
[2025-06-28 03:26:43] INFO: Starting deployment: default
[2025-06-28 03:26:43] INFO: 🚀 Executing local command 'local: echo'
[2025-06-28 03:26:43] INFO: ✅ Local command 'local: echo' completed in 0.01s
[2025-06-28 03:26:43] INFO: 📤 Output:
[2025-06-28 03:26:43] INFO:    🚀 Starting deployment of myapp v1.0.0
[2025-06-28 03:26:43] INFO: 🚀 Executing 'deploy' on deploy@192.168.1.100:22
[2025-06-28 03:26:43] INFO: ✅ Command 'deploy' completed on deploy@192.168.1.100:22 in 1.25s
[2025-06-28 03:26:43] INFO: 📤 Output:
[2025-06-28 03:26:43] INFO:    正在部署 myapp v1.0.0...
[2025-06-28 03:26:43] INFO:    Creating deployment directory...
[2025-06-28 03:26:43] INFO:    Pulling latest code...
[2025-06-28 03:26:43] INFO:    Restarting application...
[2025-06-28 03:26:43] INFO:    ✅ Deployment completed!
```

## DSL 语法参考

### 变量定义和使用

```ruby
# 全局变量定义
set 'application', 'myapp'
set 'version', '1.0.0'
set 'environment', 'production'

# 在命令中使用变量（支持两种语法）
run 'echo "Deploying {{application}} v{{version}}"'
run 'echo "Environment: ${environment}"'

# 在 heredoc 中使用变量
run <<~SCRIPT
  echo "=== {{application}} Deployment ==="
  echo "Version: {{version}}"
  echo "Environment: {{environment}}"
  echo "Hostname: {{hostname}}"  # 自动变量
SCRIPT
```

### 本地命令执行

```ruby
# 本地单行命令
local 'echo "Starting deployment process..."'
local 'uptime'
local 'df -h | head -5'

# 本地多行命令（heredoc）
local <<~PREPARATION
  echo "=== Pre-deployment Checks ==="
  echo "Current user: $(whoami)"
  echo "Current date: $(date)"
  echo "System uptime:"
  uptime
  echo "Available disk space:"
  df -h | head -5
  echo "=== Preparation completed ==="
PREPARATION

# 混合本地和远程命令
local 'echo "Starting deployment from local machine..."'

task 'deploy', on: :webservers do
  run 'echo "Deploying on remote server {{hostname}}..."'
  run 'sudo systemctl restart myapp'
end

local 'echo "🎉 Deployment process completed!"'
```

### 主机定义

#### 方式一：DSL 中直接定义

```ruby
# 基本主机定义
host '192.168.1.100'

# 完整主机定义
host '192.168.1.100',
     user: 'deploy',
     port: 22,
     roles: [:web, :app],
     vars: { env: 'production' }

# 批量主机定义
hosts({
  '192.168.1.100' => { roles: [:web], user: 'deploy' },
  '192.168.1.101' => { roles: [:db], user: 'deploy' }
})
```

#### 方式二：使用 Inventory 文件（推荐）

```ruby
# 从 inventory.yml 加载主机配置
inventory 'inventory.yml'

# 或指定其他路径
inventory 'config/production_inventory.yml'
```

**inventory.yml 示例：**

```yaml
# 全局变量
vars:
  application: myapp
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

  production:
    children:
      - webservers
      - databases
    vars:
      environment: production

# 主机配置
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

  db1.example.com:
    user: postgres
    roles: [database]
    ssh:
      key_file: ~/.ssh/db_key
```

### 任务定义

#### 基本任务

```ruby
# 基本任务
task 'deploy' do
  run 'echo "Hello World"'
end

# 指定目标主机
task 'deploy', on: :web do
  run 'sudo systemctl restart nginx'
end

# 任务选项
task 'deploy', on: [:web, :app], parallel: true, fail_fast: false do
  run 'git pull origin main'
  run 'bundle install'
  run 'sudo systemctl restart app'
end
```

#### Heredoc 语法支持

kdeploy 支持使用 heredoc 语法执行多行 shell 脚本，让复杂的部署逻辑更加清晰：

```ruby
# 使用 heredoc 语法执行多行脚本
task 'deploy_app', on: :webservers do
  run <<~DEPLOYMENT
    echo "Starting deployment to {{hostname}}..."

    # Create application directory
    sudo mkdir -p {{deploy_to}}
    sudo chown {{user}}:{{user}} {{deploy_to}}

    # Clone or update repository
    if [ -d "{{deploy_to}}/.git" ]; then
      echo "Updating existing repository..."
      cd {{deploy_to}}
      git fetch origin
      git reset --hard origin/{{branch}}
    else
      echo "Cloning repository..."
      git clone {{repo_url}} {{deploy_to}}
      cd {{deploy_to}}
      git checkout {{branch}}
    fi

    # Install dependencies and build
    npm install --production
    npm run build || echo "No build script found"

    echo "Deployment completed successfully!"
  DEPLOYMENT
end

# 带行继续符的复杂脚本
task 'system_setup' do
  run <<~SHELL
    # Install packages with line continuation
    sudo apt-get update -y
    sudo apt-get install -y \\
      curl \\
      wget \\
      git \\
      build-essential \\
      nginx

    # Configure system
    echo "System setup completed on {{hostname}}"
  SHELL
end
```

### 命令执行

```ruby
# 基本命令
run 'ls -la'

# 命令选项
run 'curl -f http://localhost/health',
    name: 'health_check',
    timeout: 30,
    retry_count: 3,
    ignore_errors: false

# 角色限制
run 'sudo systemctl restart nginx', only: :web
run 'echo "非数据库服务器"', except: :db

# 变量替换
run 'echo "Deploying to {{hostname}} as {{user}}"'
run 'cd {{deploy_to}} && git pull origin {{branch}}'
```

### 文件操作

```ruby
# 上传文件
upload 'local/file.txt', '/remote/path/file.txt'

# 下载文件
download '/remote/log/app.log', 'local/logs/'

# 上传模板文件
upload_template 'nginx.conf', '/etc/nginx/sites-available/{{application}}'
```

### ERB 模板支持

kdeploy 内置 ERB 模板引擎，支持动态生成配置文件：

#### 模板管理

```ruby
# 设置模板目录
template_dir 'templates'

# 上传渲染后的模板文件
task 'configure_nginx', on: :webservers do
  upload_template 'nginx.conf', '/etc/nginx/sites-available/{{application}}',
                  variables: {
                    server_name: '{{hostname}}',
                    upstream_port: 3000
                  }
end

# 执行渲染后的模板脚本
task 'deploy_script', on: :webservers do
  run_template 'deploy.sh',
               variables: {
                 backup_before_deploy: true,
                 restart_services: true
               }
end

# 渲染模板到字符串
rendered_config = render_template 'app.conf', { port: 8080 }
```

#### 模板文件示例

**templates/nginx.conf.erb：**

```erb
# Nginx configuration for <%= application %>
server {
    listen <%= nginx_port || 80 %>;
    server_name <%= server_name || hostname %>;

    root <%= deploy_to %>/public;

    location / {
        try_files $uri $uri/ @app;
    }

    location @app {
        proxy_pass http://127.0.0.1:<%= upstream_port || app_port || 3000 %>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
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

**templates/deploy.sh.erb：**

```erb
#!/bin/bash
# Deployment script for <%= application %>
set -e

echo "Deploying <%= application %> to <%= hostname %>"

APP_DIR="<%= deploy_to %>"
REPO_URL="<%= repo_url %>"

<% if backup_before_deploy %>
# Create backup
echo "Creating backup..."
cd $APP_DIR && git stash push -m "backup_$(date +%Y%m%d_%H%M%S)"
<% end %>

# Deploy application
cd $APP_DIR
git pull origin <%= branch || 'main' %>
npm install --production
npm run build

<% if restart_services %>
# Restart services
sudo systemctl restart <%= application %>
<% end %>

echo "Deployment completed!"
```

### 条件执行

```ruby
# 条件执行
when ENV['RAILS_ENV'] == 'production' do
  task 'deploy_production' do
    run 'RAILS_ENV=production bundle exec rake assets:precompile'
  end
end

unless File.exist?('.maintenance') do
  task 'normal_deploy' do
    run 'echo "Normal deployment"'
  end
end
```

## 命令行选项

```bash
# 基本用法（两种方式等价）
kdeploy execute script.rb
kdeploy deploy script.rb

# 指定配置文件和inventory文件
kdeploy deploy script.rb -c config/kdeploy.yml -i inventory.yml

# 详细输出
kdeploy deploy script.rb --verbose

# 干运行
kdeploy deploy script.rb --dry-run

# 日志文件
kdeploy deploy script.rb --log-file deployment.log

# 验证脚本（支持inventory）
kdeploy validate script.rb -i inventory.yml

# 查看配置
kdeploy config

# 显示版本
kdeploy version

# 初始化新项目（自动创建inventory.yml）
kdeploy init myproject

# 查看帮助
kdeploy help
kdeploy help deploy
```

## 配置文件

创建 `config/kdeploy.yml` 文件：

```yaml
# 最大并发任务数
max_concurrent_tasks: 10

# SSH 连接超时（秒）
ssh_timeout: 30

# 命令执行超时（秒）
command_timeout: 300

# 重试次数
retry_count: 3

# 重试延迟（秒）
retry_delay: 1

# 日志级别 (debug, info, warn, error, fatal)
log_level: info

# Inventory 文件路径
inventory_file: inventory.yml

# 模板文件目录
template_dir: templates

# 默认用户
default_user: deploy

# 默认端口
default_port: 22

# SSH 选项
ssh_options:
  verify_host_key: never
  non_interactive: true
  use_agent: true
  forward_agent: false
```

## 高级用法

### 并发控制

```ruby
# 全局并发设置
Kdeploy.configure do |config|
  config.max_concurrent_tasks = 5
end

# 任务级并发控制
task 'deploy', parallel: true, max_concurrent: 3 do
  run 'heavy_task.sh'
end
```

### 错误处理

```ruby
# 忽略错误继续执行
run 'optional_command', ignore_errors: true

# 失败快速停止
task 'critical_task', fail_fast: true do
  run 'important_command_1'
  run 'important_command_2'
end
```

### 混合部署模式

```ruby
# 混合本地和远程操作
local 'echo "🚀 Starting deployment from $(hostname)"'

# 准备阶段（本地）
local <<~PREPARATION
  echo "=== Pre-deployment Checks ==="
  git status
  npm test
  echo "✅ All checks passed"
PREPARATION

# 部署阶段（远程）
task 'deploy', on: :production do
  run 'echo "Deploying to {{hostname}}..."'

  run <<~DEPLOYMENT
    cd {{deploy_to}}
    git pull origin {{branch}}
    npm install --production
    sudo systemctl restart {{application}}
  DEPLOYMENT
end

# 完成阶段（本地）
local 'echo "🎉 Deployment completed successfully!"'
```

## 示例项目

### 典型的Rails应用部署

```ruby
# deploy.rb
set 'application', 'myapp'
set 'repo_url', 'git@github.com:mycompany/myapp.git'
set 'branch', 'main'
set 'deploy_to', '/var/www/myapp'

inventory 'production_inventory.yml'

# 本地准备
local 'echo "🚀 Starting Rails deployment..."'
local 'git status'

# 部署任务
task 'deploy', on: :webservers do
  run <<~DEPLOY
    echo "Deploying Rails app to {{hostname}}..."

    # Backup current release
    if [ -d "{{deploy_to}}/current" ]; then
      sudo mv {{deploy_to}}/current {{deploy_to}}/backup_$(date +%s)
    fi

    # Clone or update
    sudo mkdir -p {{deploy_to}}
    cd {{deploy_to}}

    if [ -d ".git" ]; then
      git fetch origin
      git reset --hard origin/{{branch}}
    else
      git clone {{repo_url}} .
      git checkout {{branch}}
    fi

    # Bundle and assets
    bundle install --deployment --without development test
    RAILS_ENV=production bundle exec rake assets:precompile

    # Database migration
    RAILS_ENV=production bundle exec rake db:migrate

    # Restart services
    sudo systemctl restart {{application}}
    sudo systemctl restart nginx

    echo "✅ Deployment to {{hostname}} completed!"
  DEPLOY
end

# 健康检查
task 'health_check', on: :webservers do
  run 'curl -f http://localhost/health', timeout: 30
end

local 'echo "🎉 Rails deployment completed!"'
```

## 最佳实践

1. **使用 Inventory 文件**：管理复杂的主机配置
2. **变量化配置**：使用变量避免硬编码
3. **分阶段部署**：先准备、再部署、后验证
4. **错误处理**：适当使用 `ignore_errors` 和 `fail_fast`
5. **日志记录**：使用详细输出模式进行调试
6. **模板化配置**：使用 ERB 模板生成动态配置
7. **混合操作**：结合本地和远程命令优化部署流程

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License