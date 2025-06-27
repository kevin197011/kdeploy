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
- 📝 **日志记录**: 完善的日志记录和错误处理
- 🎯 **角色管理**: 基于角色的主机分组管理

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
# 定义主机
host '192.168.1.100', user: 'deploy', roles: [:web, :app]
host '192.168.1.101', user: 'deploy', roles: [:db]

# 设置变量
set :application, 'myapp'
set :deploy_to, '/opt/myapp'

# 部署任务
task 'deploy', on: [:web, :app] do
  run 'echo "正在部署应用..."'
  run 'sudo systemctl restart myapp'
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
$ kdeploy run deploy.rb --dry-run

# 执行部署
$ kdeploy run deploy.rb
```

## DSL 语法参考

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
```

### 文件操作

```ruby
# 上传文件
upload 'local/file.txt', '/remote/path/file.txt'

# 下载文件
download '/remote/log/app.log', 'local/logs/'
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

### 变量和条件

```ruby
# 设置变量
set :env, 'production'
set :deploy_to, '/opt/myapp'

# 条件执行
when ENV['RAILS_ENV'] == 'production' do
  task 'deploy_production' do
    run 'RAILS_ENV=production bundle exec rake assets:precompile'
  end
end

# 使用变量
task 'deploy' do
  run "cd #{deploy_to} && git pull"
end
```

## 命令行选项

```bash
# 基本用法
kdeploy execute script.rb

# 指定配置文件和inventory文件
kdeploy execute script.rb -c config/kdeploy.yml -i inventory.yml

# 详细输出
kdeploy execute script.rb --verbose

# 干运行
kdeploy execute script.rb --dry-run

# 日志文件
kdeploy execute script.rb --log-file deployment.log

# 验证脚本（支持inventory）
kdeploy validate script.rb -i inventory.yml

# 查看配置
kdeploy config

# 显示版本
kdeploy version

# 初始化新项目（自动创建inventory.yml）
kdeploy init myproject
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

### 脚本包含

```ruby
# 包含其他脚本
include 'scripts/database.rb'
include 'scripts/webserver.rb'
```

## 开发

克隆项目后，运行 `bin/setup` 安装依赖。然后运行 `rake spec` 执行测试。

要在本地安装这个 gem，运行 `bundle exec rake install`。要发布新版本，更新 `version.rb` 中的版本号，然后运行 `bundle exec rake release`，这将创建一个 git 标签，推送提交和创建的标签，并将 `.gem` 文件推送到 [rubygems.org](https://rubygems.org)。

## 贡献

欢迎提交 Bug 报告和拉取请求到 https://github.com/kdeploy/kdeploy。

## 许可证

该 gem 在 [MIT License](https://opensource.org/licenses/MIT) 下提供开源许可。

## 示例

查看 `examples/` 目录获取更多使用示例：

- `examples/basic_deployment.rb` - 基本部署示例
- `examples/rails_deployment.rb` - Rails 应用部署
- `examples/multi_environment.rb` - 多环境部署
- `examples/database_migration.rb` - 数据库迁移