# Kdeploy

```
          _            _
  /\ /\__| | ___ _ __ | | ___  _   _
 / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
/ __ \ (_| |  __/ |_) | | (_) | |_| |
\/  \/\__,_|\___| .__/|_|\___/ \__, |
                |_|            |___/

⚡ 轻量级无代理部署工具
🚀 自动部署，轻松扩展
```

一个用 Ruby 编写的轻量级、无代理的部署自动化工具。Kdeploy 使您能够使用 SSH 在多个服务器上部署应用程序、管理配置和执行任务，而无需在目标机器上安装任何代理或守护进程。

[![Gem Version](https://img.shields.io/gem/v/kdeploy)](https://rubygems.org/gems/kdeploy)
[![Ruby](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**语言**: [English](README_EN.md) | [中文](README.md)

## 目录

- [功能特性](#-功能特性)
- [安装](#-安装)
- [快速开始](#-快速开始)
- [使用指南](#-使用指南)
- [配置](#-配置)
- [高级用法](#-高级用法)
- [错误处理](#-错误处理)
- [最佳实践](#-最佳实践)
- [故障排除](#-故障排除)
- [架构](#-架构)
- [开发](#-开发)
- [贡献](#-贡献)
- [许可证](#-许可证)

## 🌟 功能特性

### 核心功能

- 🔑 **无代理远程部署**: 使用 SSH 进行安全的远程执行，无需安装代理
- 📝 **优雅的 Ruby DSL**: 简单而富有表现力的任务定义语法
- 🚀 **并发执行**: 跨多个主机的高效并行任务处理
- 📤 **文件上传支持**: 通过 SCP 轻松部署文件和模板
- 📊 **任务状态跟踪**: 实时执行监控，提供详细输出
- 🔄 **ERB 模板支持**: 支持变量替换的动态配置生成
- 🎯 **基于角色的部署**: 针对特定服务器角色进行有组织的部署
- 🔍 **试运行模式**: 在执行前预览任务，不进行实际更改
- 🎨 **彩色输出**: 直观的颜色方案（绿色：成功，红色：错误，黄色：警告）
- ⚙️ **灵活的主机定位**: 在特定主机、角色或所有主机上执行任务
- 🔐 **多种身份验证方法**: 支持 SSH 密钥和密码身份验证
- 📈 **执行时间跟踪**: 监控任务执行持续时间以进行性能分析

### 技术特性

- **线程安全执行**: 基于 `concurrent-ruby` 实现可靠的并行处理
- **自定义错误处理**: 详细的错误类型，便于调试
- **配置管理**: 集中式配置，提供合理的默认值
- **可扩展架构**: 模块化设计，易于扩展
- **Shell 自动补全**: 支持 Bash 和 Zsh 的自动补全

## 📦 安装

### 要求

- Ruby >= 2.7.0
- 对目标服务器的 SSH 访问权限
- 已配置 SSH 密钥或密码身份验证

### 通过 RubyGems 安装

```bash
gem install kdeploy
```

### 通过 Bundler 安装

将以下行添加到应用程序的 `Gemfile` 中：

```ruby
gem 'kdeploy'
```

然后执行：

```bash
bundle install
```

### 验证安装

```bash
kdeploy version
```

您应该看到版本信息和横幅。

### Shell 自动补全

Kdeploy 在安装期间自动配置 shell 自动补全。如果需要，可以手动添加到 shell 配置中：

**对于 Bash** (`~/.bashrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.bash)"
```

**对于 Zsh** (`~/.zshrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.zsh)"
autoload -Uz compinit && compinit
```

添加配置后：
1. 对于 Bash: `source ~/.bashrc`
2. 对于 Zsh: `source ~/.zshrc`

现在您可以使用 Tab 补全：
- 命令: `kdeploy [TAB]`
- 文件路径: `kdeploy execute [TAB]`
- 选项: `kdeploy execute deploy.rb [TAB]`

## 🚀 快速开始

### 1. 初始化新项目

```bash
kdeploy init my-deployment
```

这将创建一个新目录，包含：
- `deploy.rb` - 主部署配置文件
- `config/` - 配置文件和模板目录
- `README.md` - 项目文档

### 2. 配置主机和任务

编辑 `deploy.rb`:

```ruby
# 定义主机
host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
host "web02", user: "ubuntu", ip: "10.0.0.2", key: "~/.ssh/id_rsa"

# 定义角色
role :web, %w[web01 web02]

# 定义部署任务
task :deploy, roles: :web do
  run <<~SHELL
    sudo systemctl stop nginx
    echo "正在部署应用程序..."
  SHELL

  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000

  run "sudo systemctl start nginx"
end
```

### 3. 运行部署

```bash
kdeploy execute deploy.rb deploy
```

## 📖 使用指南

### 命令参考

#### `kdeploy init [DIR]`

初始化新的部署项目。

```bash
# 在当前目录初始化
kdeploy init .

# 在指定目录初始化
kdeploy init my-deployment
```

#### `kdeploy execute TASK_FILE [TASK]`

从配置文件执行部署任务。

**基本用法:**
```bash
# 执行文件中的所有任务
kdeploy execute deploy.rb

# 执行特定任务
kdeploy execute deploy.rb deploy_web
```

**选项:**
- `--limit HOSTS`: 限制执行到特定主机（逗号分隔）
- `--parallel NUM`: 并行执行数量（默认: 10）
- `--dry-run`: 预览模式 - 显示将要执行的操作而不实际执行

**示例:**
```bash
# 预览部署而不执行
kdeploy execute deploy.rb deploy_web --dry-run

# 仅在特定主机上执行
kdeploy execute deploy.rb deploy_web --limit web01,web02

# 使用自定义并行数量
kdeploy execute deploy.rb deploy_web --parallel 5

# 组合选项
kdeploy execute deploy.rb deploy_web --limit web01 --parallel 3 --dry-run
```

#### `kdeploy version`

显示版本信息。

```bash
kdeploy version
```

#### `kdeploy help [COMMAND]`

显示帮助信息。

```bash
# 显示一般帮助
kdeploy help

# 显示特定命令的帮助
kdeploy help execute
```

### 主机定义

#### 基本主机配置

```ruby
# 使用 SSH 密钥的单个主机
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa"

# 使用密码身份验证的主机
host "web02",
  user: "admin",
  ip: "10.0.0.2",
  password: "your-password"

# 使用自定义 SSH 端口的主机
host "web03",
  user: "ubuntu",
  ip: "10.0.0.3",
  key: "~/.ssh/id_rsa",
  port: 2222

# 使用 sudo 的主机（所有命令自动使用 sudo）
host "web04",
  user: "ubuntu",
  ip: "10.0.0.4",
  key: "~/.ssh/id_rsa",
  use_sudo: true
```

#### 主机配置选项

| 选项 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `user` | String | 是 | SSH 用户名 |
| `ip` | String | 是 | 服务器 IP 地址或主机名 |
| `key` | String | 否* | SSH 私钥文件路径 |
| `password` | String | 否* | SSH 密码 |
| `port` | Integer | 否 | SSH 端口（默认: 22） |
| `use_sudo` | Boolean | 否 | 是否对所有命令自动使用 sudo（默认: false） |
| `sudo_password` | String | 否 | sudo 密码（如果需要密码验证） |

\* 身份验证需要 `key` 或 `password` 之一。

#### 动态主机定义

```ruby
# 以编程方式定义多个主机
%w[web01 web02 web03].each do |name|
  host name,
    user: "ubuntu",
    ip: "10.0.0.#{name[-1]}",
    key: "~/.ssh/id_rsa"
end

# 从外部源定义主机
require 'yaml'
hosts_config = YAML.load_file('hosts.yml')
hosts_config.each do |name, config|
  host name, **config
end
```

### 角色管理

角色允许您对主机进行分组，并在任务中集体定位它们。

```ruby
# 定义角色
role :web, %w[web01 web02 web03]
role :db, %w[db01 db02]
role :cache, %w[cache01]
role :all, %w[web01 web02 web03 db01 db02 cache01]

# 在任务中使用角色
task :deploy_web, roles: :web do
  # 在所有 Web 服务器上执行
end

task :backup_db, roles: :db do
  # 在所有数据库服务器上执行
end

# 多个角色
task :deploy_all, roles: [:web, :cache] do
  # 在 Web 和缓存服务器上执行
end
```

### 任务定义

#### 基本任务

```ruby
task :hello do
  run "echo 'Hello, World!'"
end
```

#### 基于角色的任务

```ruby
task :deploy_web, roles: :web do
  run "sudo systemctl restart nginx"
end
```

#### 特定主机任务

```ruby
task :maintenance, on: %w[web01] do
  run <<~SHELL
    sudo systemctl stop nginx
    sudo apt-get update && sudo apt-get upgrade -y
    sudo systemctl start nginx
  SHELL
end
```

#### 多命令任务

```ruby
task :deploy, roles: :web do
  # 停止服务
  run "sudo systemctl stop nginx"

  # 上传配置
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"

  # 启动服务
  run "sudo systemctl start nginx"

  # 验证状态
  run "sudo systemctl status nginx"
end
```

#### 任务选项

| 选项 | 类型 | 描述 |
|------|------|------|
| `roles` | Symbol/Array | 在具有指定角色的主机上执行 |
| `on` | Array | 在特定主机上执行 |

**注意**: 如果未指定 `roles` 或 `on`，任务将在所有已定义的主机上执行。

### 命令类型

#### `run` - 执行 Shell 命令

在远程服务器上执行命令。

```ruby
# 单行命令
run "sudo systemctl restart nginx"

# 多行命令（推荐用于复杂命令）
run <<~SHELL
  cd /var/www/app
  git pull origin main
  bundle install
  sudo systemctl restart puma
SHELL
```

**参数:**
- `command`: 要执行的命令字符串
- `sudo`: 布尔值，是否使用 sudo 执行此命令（可选，默认: nil，继承主机配置）

**sudo 使用方式:**

1. **在主机级别配置**（所有命令自动使用 sudo）:
```ruby
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa",
  use_sudo: true  # 所有命令自动使用 sudo
```

2. **在命令级别配置**（仅特定命令使用 sudo）:
```ruby
task :deploy do
  run "systemctl restart nginx", sudo: true  # 仅此命令使用 sudo
  run "echo 'Deployed'"  # 此命令不使用 sudo
end
```

3. **使用 sudo 密码**（如果需要密码验证）:
```ruby
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa",
  use_sudo: true,
  sudo_password: "your-sudo-password"  # 仅在需要密码时配置
```

**注意:**
- 如果命令已经以 `sudo` 开头，工具不会重复添加
- 推荐使用 NOPASSWD 配置 sudo，避免在配置文件中存储密码
- 命令级别的 `sudo` 选项会覆盖主机级别的 `use_sudo` 配置

**最佳实践**: 对多行命令使用 heredoc (`<<~SHELL`) 以提高可读性。

#### `upload` - 上传文件

将文件上传到远程服务器。

```ruby
upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
upload "./scripts/deploy.sh", "/tmp/deploy.sh"
```

**参数:**
- `source`: 本地文件路径
- `destination`: 远程文件路径

#### `upload_template` - 上传 ERB 模板

上传并渲染 ERB 模板，支持变量替换。

```ruby
upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
  domain_name: "example.com",
  port: 3000,
  worker_processes: 4
```

**参数:**
- `source`: 本地 ERB 模板文件路径
- `destination`: 远程文件路径
- `variables`: 用于模板渲染的变量哈希

### 模板支持

Kdeploy 支持 ERB（嵌入式 Ruby）模板，用于动态配置生成。

#### 创建模板

创建 ERB 模板文件（例如，`config/nginx.conf.erb`）：

```erb
user nginx;
worker_processes <%= worker_processes %>;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections <%= worker_connections %>;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream app_servers {
        server 127.0.0.1:<%= port %>;
    }

    server {
        listen 80;
        server_name <%= domain_name %>;

        location / {
            proxy_pass http://app_servers;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
```

#### 使用模板

```ruby
task :deploy_config do
  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000,
    worker_processes: 4,
    worker_connections: 2048
end
```

#### 模板特性

- 完整的 ERB 语法支持
- 变量替换
- 条件逻辑
- 循环和迭代
- Ruby 代码执行

### 清单块

使用 `inventory` 块来组织主机定义：

```ruby
inventory do
  host 'web01', user: 'ubuntu', ip: '10.0.0.1', key: '~/.ssh/id_rsa'
  host 'web02', user: 'ubuntu', ip: '10.0.0.2', key: '~/.ssh/id_rsa'
  host 'db01', user: 'root', ip: '10.0.0.3', key: '~/.ssh/id_rsa'
end
```

## ⚙️ 配置

### 默认配置

Kdeploy 使用可自定义的合理默认值：

- **默认并行数量**: 10 个并发执行
- **SSH 超时**: 30 秒
- **主机密钥验证**: 禁用（为方便起见，在生产环境中启用）

### 环境变量

您可以使用环境变量覆盖默认值：

```bash
export KDEPLOY_PARALLEL=5
export KDEPLOY_SSH_TIMEOUT=60
```

### 配置文件

对于项目特定的配置，创建 `.kdeploy.yml`：

```yaml
parallel: 5
ssh_timeout: 60
verify_host_key: true
```

配置文件会自动从当前目录向上查找，直到找到 `.kdeploy.yml` 文件。

## 🔧 高级用法

### 条件执行

在部署文件中使用 Ruby 条件：

```ruby
task :deploy do
  if ENV['ENVIRONMENT'] == 'production'
    run "sudo systemctl stop nginx"
  end

  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"

  if ENV['ENVIRONMENT'] == 'production'
    run "sudo systemctl start nginx"
  end
end
```

### 循环主机

```ruby
# 根据主机执行不同的命令
task :custom_setup do
  @hosts.each do |name, config|
    if name.start_with?('web')
      run "echo 'Web 服务器: #{name}'"
    elsif name.start_with?('db')
      run "echo '数据库服务器: #{name}'"
    end
  end
end
```

### 任务中的错误处理

```ruby
task :deploy do
  run "sudo systemctl stop nginx" || raise "停止 nginx 失败"
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
  run "sudo systemctl start nginx" || raise "启动 nginx 失败"
end
```

### 使用外部库

```ruby
require 'yaml'
require 'json'

# 从外部文件加载配置
config = YAML.load_file('config.yml')

task :deploy do
  config['commands'].each do |cmd|
    run cmd
  end
end
```

## 🚨 错误处理

### 错误类型

Kdeploy 提供特定的错误类型以便更好地调试：

- `Kdeploy::TaskNotFoundError` - 任务未找到
- `Kdeploy::HostNotFoundError` - 主机未找到
- `Kdeploy::SSHError` - SSH 操作失败
- `Kdeploy::SCPError` - SCP 上传失败
- `Kdeploy::TemplateError` - 模板渲染失败
- `Kdeploy::ConfigurationError` - 配置错误
- `Kdeploy::FileNotFoundError` - 文件未找到

### 错误输出

错误显示包括：
- 红色颜色编码
- 详细的错误消息
- 主机信息
- 原始错误上下文

## 💡 最佳实践

### 1. 对多行命令使用 Heredoc

```ruby
# ✅ 好的做法
run <<~SHELL
  cd /var/www/app
  git pull origin main
  bundle install
SHELL

# ❌ 避免
run "cd /var/www/app && git pull origin main && bundle install"
```

### 2. 使用角色进行组织

```ruby
# ✅ 好的做法 - 使用角色进行组织
role :web, %w[web01 web02]
role :db, %w[db01 db02]

task :deploy_web, roles: :web do
  # ...
end

# ❌ 避免 - 硬编码主机名
task :deploy do
  # 难以维护
end
```

### 3. 使用模板进行动态配置

```ruby
# ✅ 好的做法 - 使用模板
upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
  domain_name: "example.com",
  port: 3000

# ❌ 避免 - 硬编码值
run "echo 'server_name example.com;' > /etc/nginx/nginx.conf"
```

### 4. 部署前验证

```ruby
task :deploy do
  # 验证配置
  run "nginx -t" || raise "Nginx 配置无效"

  # 部署
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
  run "sudo systemctl reload nginx"
end
```

### 5. 使用试运行进行测试

在实际部署之前，始终使用 `--dry-run` 进行测试：

```bash
kdeploy execute deploy.rb deploy_web --dry-run
```

### 6. 正确组织文件

```
project/
├── deploy.rb              # 主部署文件
├── config/                # 配置文件
│   ├── nginx.conf.erb     # 模板
│   └── app.conf           # 静态配置
└── scripts/               # 辅助脚本
    └── deploy.sh
```

### 7. 版本控制

- 提交 `deploy.rb` 和模板
- 使用 `.gitignore` 处理敏感文件
- 将密钥存储在环境变量中

### 8. 并行执行

根据您的基础设施调整并行数量：

```bash
# 对于许多主机，增加并行数量
kdeploy execute deploy.rb deploy --parallel 20

# 对于有限资源，减少
kdeploy execute deploy.rb deploy --parallel 3
```

## 🔍 故障排除

### 常见问题

#### SSH 身份验证失败

**问题**: `SSH authentication failed`

**解决方案**:
1. 验证 SSH 密钥路径是否正确
2. 检查密钥权限: `chmod 600 ~/.ssh/id_rsa`
3. 手动测试 SSH 连接: `ssh user@host`
4. 验证用户名和 IP 地址

#### 主机未找到

**问题**: `No hosts found for task`

**解决方案**:
1. 验证任务中的主机名是否与已定义的主机匹配
2. 检查角色定义
3. 如果使用了 `--limit` 选项，请验证

#### 命令执行失败

**问题**: 远程服务器上的命令失败

**解决方案**:
1. 在目标服务器上手动测试命令
2. 检查用户权限（可能需要 sudo）
3. 验证命令语法
4. 检查服务器日志

#### 模板渲染错误

**问题**: 模板上传失败

**解决方案**:
1. 验证模板中的 ERB 语法
2. 检查是否提供了所有必需的变量
3. 验证模板文件是否存在
4. 在本地测试模板渲染

#### 连接超时

**问题**: SSH 连接超时

**解决方案**:
1. 检查网络连接
2. 验证防火墙规则
3. 在配置中增加超时时间
4. 检查目标服务器上的 SSH 服务

## 🏗️ 架构

### 核心组件

- **CLI** (`cli.rb`): 使用 Thor 的命令行界面
- **DSL** (`dsl.rb`): 用于任务定义的领域特定语言
- **Executor** (`executor.rb`): SSH/SCP 执行引擎
- **Runner** (`runner.rb`): 并发任务执行协调器
- **CommandExecutor** (`command_executor.rb`): 单个命令执行
- **CommandGrouper** (`command_grouper.rb`): 命令分组逻辑
- **Template** (`template.rb`): ERB 模板渲染
- **Output** (`output.rb`): 输出格式化和显示
- **Configuration** (`configuration.rb`): 配置管理
- **Errors** (`errors.rb`): 自定义错误类型

### 执行流程

1. **解析配置**: 加载并解析 `deploy.rb`
2. **解析主机**: 根据任务定义确定目标主机
3. **分组命令**: 按类型分组命令以提高执行效率
4. **并发执行**: 跨主机并行运行任务
5. **收集结果**: 收集执行结果和状态
6. **显示输出**: 格式化并向用户显示结果

### 并发模型

Kdeploy 使用带有固定线程池的 `concurrent-ruby`：
- 默认: 10 个并发执行
- 可通过 `--parallel` 选项配置
- 线程安全的结果收集
- 自动资源清理

## 🔧 开发

### 设置开发环境

```bash
# 克隆仓库
git clone https://github.com/kevin197011/kdeploy.git
cd kdeploy

# 安装依赖
bundle install

# 运行测试
bundle exec rspec

# 运行控制台
bin/console
```

### 项目结构

```
kdeploy/
├── lib/
│   └── kdeploy/
│       ├── cli.rb              # CLI 接口
│       ├── dsl.rb              # DSL 定义
│       ├── executor.rb         # SSH/SCP 执行器
│       ├── runner.rb           # 任务运行器
│       ├── command_executor.rb # 命令执行器
│       ├── command_grouper.rb  # 命令分组器
│       ├── template.rb         # 模板处理器
│       ├── output.rb           # 输出接口
│       ├── configuration.rb    # 配置
│       ├── errors.rb           # 错误类型
│       └── ...
├── spec/                       # 测试
├── exe/                        # 可执行文件
├── sample/                     # 示例项目
└── README.md                   # 本文档
```

### 运行测试

```bash
# 运行所有测试
bundle exec rspec

# 运行特定测试文件
bundle exec rspec spec/kdeploy_spec.rb

# 运行覆盖率
COVERAGE=true bundle exec rspec
```

### 构建 Gem

```bash
# 构建 gem
gem build kdeploy.gemspec

# 本地安装
gem install ./kdeploy-*.gem
```

### 代码风格

项目使用 RuboCop 进行代码风格检查：

```bash
# 检查风格
bundle exec rubocop

# 自动修复问题
bundle exec rubocop -a
```

## 🤝 贡献

欢迎贡献！请遵循以下步骤：

1. **Fork 仓库**
2. **创建功能分支**: `git checkout -b feature/my-new-feature`
3. **进行更改**: 遵循代码风格并添加测试
4. **提交更改**: 使用约定式提交消息
5. **推送到分支**: `git push origin feature/my-new-feature`
6. **创建 Pull Request**: 提供清晰的更改描述

### 贡献指南

- 遵循现有代码风格
- 为新功能添加测试
- 更新文档
- 确保所有测试通过
- 遵循约定式提交格式

### 提交消息格式

遵循 [约定式提交](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

类型: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## 📚 示例

### 示例项目

查看 [示例项目](https://github.com/kevin197011/kdeploy-app) 以获取完整的部署设置。

### 常见部署场景

#### Web 应用程序部署

```ruby
host "web01", user: "deploy", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
role :web, %w[web01]

task :deploy_app, roles: :web do
  run <<~SHELL
    cd /var/www/app
    git pull origin main
    bundle install
    rake db:migrate
    sudo systemctl restart puma
  SHELL
end
```

#### 数据库备份

```ruby
host "db01", user: "postgres", ip: "10.0.0.10", key: "~/.ssh/id_rsa"
role :db, %w[db01]

task :backup, roles: :db do
  run <<~SHELL
    pg_dump mydb > /tmp/backup_$(date +%Y%m%d).sql
    gzip /tmp/backup_*.sql
    aws s3 cp /tmp/backup_*.sql.gz s3://backups/
    rm /tmp/backup_*.sql.gz
  SHELL
end
```

#### 配置管理

```ruby
task :update_config, roles: :web do
  upload_template "./config/app.yml.erb", "/etc/app/config.yml",
    environment: "production",
    database_url: ENV['DATABASE_URL'],
    redis_url: ENV['REDIS_URL']

  run "sudo systemctl reload app"
end
```

## 📝 许可证

该 gem 在 [MIT 许可证](https://opensource.org/licenses/MIT) 条款下作为开源提供。

## 🔗 链接

- **GitHub**: https://github.com/kevin197011/kdeploy
- **RubyGems**: https://rubygems.org/gems/kdeploy
- **Issues**: https://github.com/kevin197011/kdeploy/issues
- **示例项目**: https://github.com/kevin197011/kdeploy-app

## 🙏 致谢

- 使用 [Thor](https://github.com/rails/thor) 构建 CLI
- 使用 [net-ssh](https://github.com/net-ssh/net-ssh) 进行 SSH 操作
- 由 [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) 提供并发支持

---

**为 DevOps 社区用 ❤️ 制作**

