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

A lightweight, agentless deployment automation tool written in Ruby. Kdeploy enables you to deploy applications, manage configurations, and execute tasks across multiple servers using SSH, without requiring any agents or daemons on target machines.

[![Gem Version](https://img.shields.io/gem/v/kdeploy)](https://rubygems.org/gems/kdeploy)
[![Ruby](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Language**: [English](README_EN.md) | [中文](README.md)

## Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Configuration](#-configuration)
- [Advanced Usage](#-advanced-usage)
- [Error Handling](#-error-handling)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)
- [Architecture](#-architecture)
- [Development](#-development)
- [Contributing](#-contributing)
- [License](#-license)

## 🌟 Features

### Core Features

- 🔑 **Agentless Remote Deployment**: Uses SSH for secure remote execution, no agents required
- 📝 **Elegant Ruby DSL**: Simple and expressive task definition syntax
- 🚀 **Concurrent Execution**: Efficient parallel task processing across multiple hosts
- 📤 **File Upload Support**: Easy file and template deployment via SCP
- 📊 **Task Status Tracking**: Real-time execution monitoring with detailed output
- 🔄 **ERB Template Support**: Dynamic configuration generation with variable substitution
- 🎯 **Role-based Deployment**: Target specific server roles for organized deployments
- 🔍 **Dry Run Mode**: Preview tasks before execution without making changes
- 🎨 **Color-coded Output**: Intuitive color scheme (Green: success, Red: errors, Yellow: warnings)
- ⚙️ **Flexible Host Targeting**: Execute tasks on specific hosts, roles, or all hosts
- 🔐 **Multiple Authentication Methods**: Support for SSH keys and password authentication
- 📈 **Execution Time Tracking**: Monitor task execution duration for performance analysis

### Technical Features

- **Thread-safe Execution**: Built on `concurrent-ruby` for reliable parallel processing
- **Custom Error Handling**: Detailed error types for better debugging
- **Configuration Management**: Centralized configuration with sensible defaults
- **Extensible Architecture**: Modular design for easy extension
- **Shell Completion**: Auto-completion support for Bash and Zsh

## 📦 Installation

### Requirements

- Ruby >= 2.7.0
- SSH access to target servers
- SSH keys or password authentication configured

### Install via RubyGems

```bash
gem install kdeploy
```

### Install via Bundler

Add this line to your application's `Gemfile`:

```ruby
gem 'kdeploy'
```

And then execute:

```bash
bundle install
```

### Verify Installation

```bash
kdeploy version
```

You should see the version information and banner.

### Shell Completion

Kdeploy automatically configures shell completion during installation. If needed, manually add to your shell config:

**For Bash** (`~/.bashrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.bash)"
```

**For Zsh** (`~/.zshrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.zsh)"
autoload -Uz compinit && compinit
```

After adding the configuration:
1. For Bash: `source ~/.bashrc`
2. For Zsh: `source ~/.zshrc`

Now you can use Tab completion for:
- Commands: `kdeploy [TAB]`
- File paths: `kdeploy execute [TAB]`
- Options: `kdeploy execute deploy.rb [TAB]`

## 🚀 Quick Start

### 1. Initialize a New Project

```bash
kdeploy init my-deployment
```

This creates a new directory with:
- `deploy.rb` - Main deployment configuration file
- `config/` - Directory for configuration files and templates
- `README.md` - Project documentation

### 2. Configure Hosts and Tasks

Edit `deploy.rb`:

```ruby
# Define hosts
host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
host "web02", user: "ubuntu", ip: "10.0.0.2", key: "~/.ssh/id_rsa"

# Define roles
role :web, %w[web01 web02]

# Define deployment task
task :deploy, roles: :web do
  run <<~SHELL
    sudo systemctl stop nginx
    echo "Deploying application..."
  SHELL

  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000

  run "sudo systemctl start nginx"
end
```

### 3. Run Deployment

```bash
kdeploy execute deploy.rb deploy
```

## 📖 Usage Guide

### Command Reference

#### `kdeploy init [DIR]`

Initialize a new deployment project.

```bash
# Initialize in current directory
kdeploy init .

# Initialize in named directory
kdeploy init my-deployment
```

#### `kdeploy execute TASK_FILE [TASK]`

Execute deployment tasks from a configuration file.

**Basic Usage:**
```bash
# Execute all tasks in the file
kdeploy execute deploy.rb

# Execute a specific task
kdeploy execute deploy.rb deploy_web
```

**Options:**
- `--limit HOSTS`: Limit execution to specific hosts (comma-separated)
- `--parallel NUM`: Number of parallel executions (default: 10)
- `--dry-run`: Preview mode - show what would be done without executing
- `--debug`: Debug mode - show detailed stdout/stderr output for `run` steps
- `--no-banner`: Do not print banner (automation-friendly)
- `--format FORMAT`: Output format (`text`|`json`, default `text`)
- `--retries N`: Retry count for network operations (default `0`)
- `--retry-delay SECONDS`: Delay between retries in seconds (default `1`)

**Examples:**
```bash
# Preview deployment without executing
kdeploy execute deploy.rb deploy_web --dry-run

# Execute on specific hosts only
kdeploy execute deploy.rb deploy_web --limit web01,web02

# Use custom parallel count
kdeploy execute deploy.rb deploy_web --parallel 5

# Show detailed stdout/stderr output
kdeploy execute deploy.rb deploy_web --debug

# Machine-readable JSON output
kdeploy execute deploy.rb deploy_web --format json --no-banner

# Retry transient network failures
kdeploy execute deploy.rb deploy_web --retries 3 --retry-delay 1

# Combine options
kdeploy execute deploy.rb deploy_web --limit web01 --parallel 3 --dry-run
```

#### `kdeploy version`

Show version information.

```bash
kdeploy version
```

#### `kdeploy help [COMMAND]`

Show help information.

```bash
# Show general help
kdeploy help

# Show help for specific command
kdeploy help execute
```

### Host Definition

#### Basic Host Configuration

```ruby
# Single host with SSH key
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa"

# Host with password authentication
host "web02",
  user: "admin",
  ip: "10.0.0.2",
  password: "your-password"

# Host with custom SSH port
host "web03",
  user: "ubuntu",
  ip: "10.0.0.3",
  key: "~/.ssh/id_rsa",
  port: 2222

# Host with sudo (all commands automatically use sudo)
host "web04",
  user: "ubuntu",
  ip: "10.0.0.4",
  key: "~/.ssh/id_rsa",
  use_sudo: true
```

#### Host Configuration Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `user` | String | Yes | SSH username |
| `ip` | String | Yes | Server IP address or hostname |
| `key` | String | No* | Path to SSH private key file |
| `password` | String | No* | SSH password |
| `port` | Integer | No | SSH port (default: 22) |
| `use_sudo` | Boolean | No | Automatically use sudo for all commands (default: false) |
| `sudo_password` | String | No | sudo password (if password authentication is required) |

\* Either `key` or `password` is required for authentication.

#### Dynamic Host Definition

```ruby
# Define multiple hosts programmatically
%w[web01 web02 web03].each do |name|
  host name,
    user: "ubuntu",
    ip: "10.0.0.#{name[-1]}",
    key: "~/.ssh/id_rsa"
end

# Define hosts from external source
require 'yaml'
hosts_config = YAML.load_file('hosts.yml')
hosts_config.each do |name, config|
  host name, **config
end
```

### Role Management

Roles allow you to group hosts and target them collectively in tasks.

```ruby
# Define roles
role :web, %w[web01 web02 web03]
role :db, %w[db01 db02]
role :cache, %w[cache01]
role :all, %w[web01 web02 web03 db01 db02 cache01]

# Use roles in tasks
task :deploy_web, roles: :web do
  # Executes on all web servers
end

task :backup_db, roles: :db do
  # Executes on all database servers
end

# Multiple roles
task :deploy_all, roles: [:web, :cache] do
  # Executes on web and cache servers
end
```

### Task Definition

#### Basic Task

```ruby
task :hello do
  run "echo 'Hello, World!'"
end
```

#### Role-based Task

```ruby
task :deploy_web, roles: :web do
  run "sudo systemctl restart nginx"
end
```

#### Host-specific Task

```ruby
task :maintenance, on: %w[web01] do
  run <<~SHELL
    sudo systemctl stop nginx
    sudo apt-get update && sudo apt-get upgrade -y
    sudo systemctl start nginx
  SHELL
end
```

#### Task with Multiple Commands

```ruby
task :deploy, roles: :web do
  # Stop service
  run "sudo systemctl stop nginx"

  # Upload configuration
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"

  # Start service
  run "sudo systemctl start nginx"

  # Verify status
  run "sudo systemctl status nginx"
end
```

#### Task Options

| Option | Type | Description |
|-------|------|-------------|
| `roles` | Symbol/Array | Execute on hosts with specified role(s) |
| `on` | Array | Execute on specific host(s) |

**Note**: If neither `roles` nor `on` is specified, the task executes on all defined hosts.

### Command Types

#### `run` - Execute Shell Commands

Execute commands on remote servers.

```ruby
# Single line command
run "sudo systemctl restart nginx"

# Multi-line command (recommended for complex commands)
run <<~SHELL
  cd /var/www/app
  git pull origin main
  bundle install
  sudo systemctl restart puma
SHELL
```

**Parameters:**
- `command`: Command string to execute
- `sudo`: Boolean, whether to execute this command with sudo (optional, default: nil, inherits host configuration)

**Using sudo:**

1. **At host level** (all commands automatically use sudo):
```ruby
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa",
  use_sudo: true  # All commands automatically use sudo
```

2. **At command level** (only specific commands use sudo):
```ruby
task :deploy do
  run "systemctl restart nginx", sudo: true  # Only this command uses sudo
  run "echo 'Deployed'"  # This command does not use sudo
end
```

3. **With sudo password** (if password authentication is required):
```ruby
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa",
  use_sudo: true,
  sudo_password: "your-sudo-password"  # Only configure if password is required
```

**Notes:**
- If the command already starts with `sudo`, the tool will not add it again
- It's recommended to use NOPASSWD sudo configuration to avoid storing passwords in configuration files
- Command-level `sudo` option overrides host-level `use_sudo` configuration

**Best Practice**: Use heredoc (`<<~SHELL`) for multi-line commands to improve readability.

#### `upload` - Upload Files

Upload files to remote servers.

```ruby
upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
upload "./scripts/deploy.sh", "/tmp/deploy.sh"
```

**Parameters:**
- `source`: Local file path
- `destination`: Remote file path

#### `upload_template` - Upload ERB Templates

Upload and render ERB templates with variable substitution.

```ruby
upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
  domain_name: "example.com",
  port: 3000,
  worker_processes: 4
```

**Parameters:**
- `source`: Local ERB template file path
- `destination`: Remote file path
- `variables`: Hash of variables for template rendering

### Chef-Style Resource DSL

Kdeploy provides a declarative resource DSL similar to Chef, which can replace or mix with low-level primitives (`run`, `upload`, `upload_template`).

#### `package` - Install System Packages

```ruby
package "nginx"
package "nginx", version: "1.18"
package "nginx", platform: :yum  # CentOS/RHEL
```

Uses apt (Ubuntu/Debian) by default; `platform: :yum` generates yum commands.

#### `service` - Manage System Services (systemd)

```ruby
service "nginx", action: [:enable, :start]
service "nginx", action: :restart
service "nginx", action: [:stop, :disable]
```

Supports `:start`, `:stop`, `:restart`, `:reload`, `:enable`, `:disable`.

#### `template` - Deploy ERB Templates

```ruby
template "/etc/nginx/nginx.conf", source: "./config/nginx.conf.erb", variables: { port: 3000 }
# Or block syntax
template "/etc/app.conf" do
  source "./config/app.erb"
  variables(domain: "example.com")
end
```

#### `file` - Upload Local Files

```ruby
file "/etc/nginx/conf.d/app.conf", source: "./config/app.conf"
```

#### `directory` - Ensure Remote Directory Exists

```ruby
directory "/etc/nginx/conf.d"
directory "/var/log/app", mode: "0755"
```

**Example: Deploy Nginx Using Resource DSL**

```ruby
task :deploy_nginx, roles: :web do
  package "nginx"
  directory "/etc/nginx/conf.d"
  template "/etc/nginx/nginx.conf", source: "./config/nginx.conf.erb", variables: { port: 3000 }
  file "/etc/nginx/conf.d/app.conf", source: "./config/app.conf"
  run "nginx -t"
  service "nginx", action: [:enable, :restart]
end
```

### Template Support

Kdeploy supports ERB (Embedded Ruby) templates for dynamic configuration generation.

#### Creating Templates

Create an ERB template file (e.g., `config/nginx.conf.erb`):

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

#### Using Templates

```ruby
task :deploy_config do
  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000,
    worker_processes: 4,
    worker_connections: 2048
end
```

#### Template Features

- Full ERB syntax support
- Variable substitution
- Conditional logic
- Loops and iterations
- Ruby code execution

### Inventory Block

Use the `inventory` block to organize host definitions:

```ruby
inventory do
  host 'web01', user: 'ubuntu', ip: '10.0.0.1', key: '~/.ssh/id_rsa'
  host 'web02', user: 'ubuntu', ip: '10.0.0.2', key: '~/.ssh/id_rsa'
  host 'db01', user: 'root', ip: '10.0.0.3', key: '~/.ssh/id_rsa'
end
```

## ⚙️ Configuration

### Default Configuration

Kdeploy uses sensible defaults that can be customized:

- **Default Parallel Count**: 10 concurrent executions
- **SSH Timeout**: 30 seconds
- **Host Key Verification**: Disabled (for convenience, enable in production)

### Environment Variables

You can override defaults using environment variables:

```bash
export KDEPLOY_PARALLEL=5
export KDEPLOY_SSH_TIMEOUT=60
```

### Configuration File

For project-specific configuration, create a `.kdeploy.yml`:

```yaml
parallel: 5
ssh_timeout: 60
verify_host_key: true
```

## 🔧 Advanced Usage

### Conditional Execution

Use Ruby conditionals in your deployment files:

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

### Looping Over Hosts

```ruby
# Execute different commands based on host
task :custom_setup do
  @hosts.each do |name, config|
    if name.start_with?('web')
      run "echo 'Web server: #{name}'"
    elsif name.start_with?('db')
      run "echo 'Database server: #{name}'"
    end
  end
end
```

### Error Handling in Tasks

```ruby
task :deploy do
  run "sudo systemctl stop nginx" || raise "Failed to stop nginx"
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
  run "sudo systemctl start nginx" || raise "Failed to start nginx"
end
```

### Using External Libraries

```ruby
require 'yaml'
require 'json'

# Load configuration from external files
config = YAML.load_file('config.yml')

task :deploy do
  config['commands'].each do |cmd|
    run cmd
  end
end
```

### Task Dependencies

While Kdeploy doesn't have built-in task dependencies, you can achieve this with Ruby:

```ruby
task :setup do
  run "echo 'Setting up...'"
end

task :deploy do
  # Manually call setup task
  self.class.kdeploy_tasks[:setup][:block].call.each do |cmd|
    case cmd[:type]
    when :run
      run cmd[:command]
    when :upload
      upload cmd[:source], cmd[:destination]
    end
  end

  run "echo 'Deploying...'"
end
```

## 🚨 Error Handling

### Error Types

Kdeploy provides specific error types for better debugging:

- `Kdeploy::TaskNotFoundError` - Task not found
- `Kdeploy::HostNotFoundError` - Host not found
- `Kdeploy::SSHError` - SSH operation failed
- `Kdeploy::SCPError` - SCP upload failed
- `Kdeploy::TemplateError` - Template rendering failed
- `Kdeploy::ConfigurationError` - Configuration error
- `Kdeploy::FileNotFoundError` - File not found

### Error Output

Errors are displayed with:
- Red color coding
- Detailed error messages
- Host information
- Original error context

### Handling Errors

```ruby
# In your deployment file
begin
  task :deploy do
    run "risky-command"
  end
rescue Kdeploy::SSHError => e
  puts "SSH Error: #{e.message}"
  # Handle error
end
```

## 💡 Best Practices

### 1. Use Heredoc for Multi-line Commands

```ruby
# ✅ Good
run <<~SHELL
  cd /var/www/app
  git pull origin main
  bundle install
SHELL

# ❌ Avoid
run "cd /var/www/app && git pull origin main && bundle install"
```

### 2. Organize with Roles

```ruby
# ✅ Good - Use roles for organization
role :web, %w[web01 web02]
role :db, %w[db01 db02]

task :deploy_web, roles: :web do
  # ...
end

# ❌ Avoid - Hardcoding host names
task :deploy do
  # Hard to maintain
end
```

### 3. Use Templates for Dynamic Configuration

```ruby
# ✅ Good - Use templates
upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
  domain_name: "example.com",
  port: 3000

# ❌ Avoid - Hardcoding values
run "echo 'server_name example.com;' > /etc/nginx/nginx.conf"
```

### 4. Validate Before Deployment

```ruby
task :deploy do
  # Validate configuration
  run "nginx -t" || raise "Nginx configuration is invalid"

  # Deploy
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
  run "sudo systemctl reload nginx"
end
```

### 5. Use Dry Run for Testing

Always test with `--dry-run` before actual deployment:

```bash
kdeploy execute deploy.rb deploy_web --dry-run
```

### 6. Organize Files Properly

```
project/
├── deploy.rb              # Main deployment file
├── config/                # Configuration files
│   ├── nginx.conf.erb     # Templates
│   └── app.conf           # Static configs
└── scripts/               # Helper scripts
    └── deploy.sh
```

### 7. Version Control

- Commit `deploy.rb` and templates
- Use `.gitignore` for sensitive files
- Store secrets in environment variables

### 8. Parallel Execution

Adjust parallel count based on your infrastructure:

```bash
# For many hosts, increase parallel count
kdeploy execute deploy.rb deploy --parallel 20

# For limited resources, decrease
kdeploy execute deploy.rb deploy --parallel 3
```

## 🔍 Troubleshooting

### Common Issues

#### SSH Authentication Failed

**Problem**: `SSH authentication failed`

**Solutions**:
1. Verify SSH key path is correct
2. Check key permissions: `chmod 600 ~/.ssh/id_rsa`
3. Test SSH connection manually: `ssh user@host`
4. Verify username and IP address

#### Host Not Found

**Problem**: `No hosts found for task`

**Solutions**:
1. Verify host names in task match defined hosts
2. Check role definitions
3. Verify `--limit` option if used

#### Command Execution Failed

**Problem**: Commands fail on remote server

**Solutions**:
1. Test commands manually on target server
2. Check user permissions (may need sudo)
3. Verify command syntax
4. Check server logs

#### Template Rendering Error

**Problem**: Template upload fails

**Solutions**:
1. Verify ERB syntax in template
2. Check all required variables are provided
3. Validate template file exists
4. Test template rendering locally

#### Connection Timeout

**Problem**: SSH connection times out

**Solutions**:
1. Check network connectivity
2. Verify firewall rules
3. Increase timeout in configuration
4. Check SSH service on target server

### Debug Mode

Enable verbose output by checking the execution output. Kdeploy provides detailed information about:
- Task execution status
- Command output
- Error messages
- Execution duration

### Getting Help

- Check [GitHub Issues](https://github.com/kevin197011/kdeploy/issues)
- Review example projects
- Read the documentation
- Ask in discussions

## 🏗️ Architecture

### Core Components

- **CLI** (`cli.rb`): Command-line interface using Thor
- **DSL** (`dsl.rb`): Domain-specific language for task definition
- **Executor** (`executor.rb`): SSH/SCP execution engine
- **Runner** (`runner.rb`): Concurrent task execution coordinator
- **CommandExecutor** (`command_executor.rb`): Individual command execution
- **Template** (`template.rb`): ERB template rendering
- **Output** (`output.rb`): Output formatting and display
- **Configuration** (`configuration.rb`): Configuration management
- **Errors** (`errors.rb`): Custom error types

### Execution Flow

1. **Parse Configuration**: Load and parse `deploy.rb`
2. **Resolve Hosts**: Determine target hosts based on task definition
3. **Execute Concurrently**: Run tasks in parallel across hosts, executing commands in order per host
4. **Collect Results**: Gather execution results and status
5. **Display Output**: Format and display results to user

### Concurrency Model

Kdeploy uses `concurrent-ruby` with a fixed thread pool:
- Default: 10 concurrent executions
- Configurable via `--parallel` option
- Thread-safe result collection
- Automatic resource cleanup

## 🔧 Development

### Setup Development Environment

```bash
# Clone repository
git clone https://github.com/kevin197011/kdeploy.git
cd kdeploy

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run console
bin/console
```

### Project Structure

```
kdeploy/
├── lib/
│   └── kdeploy/
│       ├── cli.rb              # CLI interface
│       ├── dsl.rb              # DSL definition
│       ├── executor.rb         # SSH/SCP executor
│       ├── runner.rb           # Task runner
│       ├── command_executor.rb # Command executor
│       ├── template.rb         # Template handler
│       ├── output.rb           # Output interface
│       ├── configuration.rb    # Configuration
│       ├── errors.rb           # Error types
│       └── ...
├── spec/                       # Tests
├── exe/                        # Executables
├── sample/                     # Example projects
└── README.md                   # This file
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/kdeploy_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Building the Gem

```bash
# Build gem
gem build kdeploy.gemspec

# Install locally
gem install ./kdeploy-*.gem
```

### Code Style

The project uses RuboCop for code style:

```bash
# Check style
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-new-feature`
3. **Make your changes**: Follow the code style and add tests
4. **Commit your changes**: Use conventional commit messages
5. **Push to the branch**: `git push origin feature/my-new-feature`
6. **Create a Pull Request**: Provide a clear description of changes

### Contribution Guidelines

- Follow existing code style
- Add tests for new features
- Update documentation
- Ensure all tests pass
- Follow conventional commit format

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## 📚 Examples

### Example Projects

Check out the [example project](https://github.com/kevin197011/kdeploy-app) for a complete deployment setup.

### Common Deployment Scenarios

#### Web Application Deployment

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

#### Database Backup

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

#### Configuration Management

```ruby
task :update_config, roles: :web do
  upload_template "./config/app.yml.erb", "/etc/app/config.yml",
    environment: "production",
    database_url: ENV['DATABASE_URL'],
    redis_url: ENV['REDIS_URL']

  run "sudo systemctl reload app"
end
```

## 📝 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🔗 Links

- **GitHub**: https://github.com/kevin197011/kdeploy
- **RubyGems**: https://rubygems.org/gems/kdeploy
- **Issues**: https://github.com/kevin197011/kdeploy/issues
- **Example Project**: https://github.com/kevin197011/kdeploy-app

## 🙏 Acknowledgments

- Built with [Thor](https://github.com/rails/thor) for CLI
- Uses [net-ssh](https://github.com/net-ssh/net-ssh) for SSH operations
- Powered by [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) for concurrency

---

**Made with ❤️ for the DevOps community**
