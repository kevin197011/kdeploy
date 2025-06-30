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

Kdeploy is a modern, lightweight agentless deployment tool similar to Chef, Puppet, and Ansible. It uses an elegant Ruby DSL syntax and supports concurrent execution, statistical analysis, and complete deployment lifecycle management.

[中文文档](README_CN.md)

## ✨ Features

- 🚀 **Lightweight**: No agent installation required on target servers, SSH-based connections
- 🎨 **Modern Interface**: Beautiful ASCII art and colored output interface
- 🔧 **DSL Syntax**: Concise and elegant Ruby DSL configuration syntax
- ⚡ **Concurrent Execution**: Support for multi-host parallel operations and intelligent concurrency control
- 🛠️ **Batch Operations**: Efficient batch Shell command execution
- 🔒 **Secure Connection**: SSH-based secure connections with key authentication
- 📝 **Real-time Output**: Command execution results with real-time display and detailed timing statistics
- 🎯 **Role Management**: Flexible role-based host grouping management
- 📋 **Inventory Management**: Powerful YAML format host inventory with group and variable inheritance
- 🧩 **Heredoc Syntax**: Support for multi-line Shell scripts using heredoc syntax
- 🎨 **ERB Templates**: Built-in ERB template engine for dynamic configuration file generation
- 🏷️ **Variable Substitution**: Support for both `{{variable}}` and `${variable}` template syntax
- 🖥️ **Mixed Execution**: Support for local command execution and hybrid deployment scenarios
- 📊 **Statistics Analysis**: Automatic deployment statistics collection with performance analysis and trend monitoring
- 🔄 **Script Library**: Rich pre-made script templates covering the complete deployment lifecycle
- 🧩 **Modular Architecture**: Support for modular script organization with reusable task components
- 🛡️ **Error Recovery**: Intelligent error handling and automatic retry mechanism

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'kdeploy'
```

Then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install kdeploy
```

## 🚀 Quick Start

### 1. Initialize Project

```bash
kdeploy init myapp
cd myapp
```

Kdeploy will automatically create a complete project structure with several useful script examples:

```
myapp/
├── deploy.rb                    # Main deployment script
├── inventory.yml               # Host inventory configuration
├── config/                     # Configuration directory
│   └── kdeploy.yml            # Global configuration file
├── scripts/                   # 🆕 Complete script library
│   ├── common_tasks.rb        # 🆕 Common task module (reusable)
│   ├── setup.rb              # Server initialization
│   ├── database.rb            # Database management
│   ├── backup.rb              # Backup operations
│   ├── monitoring.rb          # Monitoring and health checks
│   ├── rollback.rb            # Rollback operations
│   └── cleanup.rb             # Cleanup maintenance
└── templates/                 # ERB template files
    ├── nginx.conf.erb         # Nginx configuration template
    ├── app.service.erb        # Systemd service template
    ├── deploy.sh.erb          # Deployment script template
    └── backup.sh.erb          # Backup script template
```

### 2. Configure Server Inventory

Edit `inventory.yml` to configure host inventory:

```yaml
# Global variables
vars:
  application: myapp
  version: 1.0.0
  deploy_to: /opt/myapp
  environment: production

# Host groups
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

# Host configurations
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

### 3. Use Pre-made Scripts

Kdeploy provides a complete script library covering various deployment stages:

#### 🔧 Server Initialization
```bash
# Execute before first deployment to install dependencies and configure environment
kdeploy deploy scripts/setup.rb
```

#### 💾 Database Management
```bash
# Database operations
kdeploy deploy scripts/database.rb  # Create database, migrate, backup
```

#### 🚀 Application Deployment
```bash
# Main application deployment
kdeploy deploy deploy.rb
```

#### 📊 Health Monitoring
```bash
# System and application health checks
kdeploy deploy scripts/monitoring.rb
```

#### 💾 Backup Operations
```bash
# Application and data backup
kdeploy deploy scripts/backup.rb
```

#### 🔙 Rollback Operations
```bash
# Emergency rollback and recovery
kdeploy deploy scripts/rollback.rb
```

#### 🧹 Cleanup Maintenance
```bash
# System cleanup and maintenance
kdeploy deploy scripts/cleanup.rb
```

#### 🧩 Common Task Module
```bash
# Use common task module for basic setup
kdeploy deploy scripts/common_tasks.rb --task setup_environment

# Execute security hardening
kdeploy deploy scripts/common_tasks.rb --task security_hardening
```

### 4. Deployment Workflow Example

```bash
# 1. Validate configuration
kdeploy validate deploy.rb

# 2. First-time server setup
kdeploy deploy scripts/setup.rb

# 3. Setup database
kdeploy deploy scripts/database.rb

# 4. Execute application deployment
kdeploy deploy deploy.rb --verbose

# 5. Health check
kdeploy deploy scripts/monitoring.rb

# 6. View statistics
kdeploy stats summary
```

## 📊 Statistics and Monitoring

Kdeploy provides powerful built-in statistics functionality that automatically tracks all deployment activities:

### 📈 Automatically Collected Statistics

- ✅ **Success/Failure Statistics**: Success rates at deployment, task, and command levels
- ⏱️ **Performance Metrics**: Detailed execution time and performance data
- 📅 **Historical Trends**: Performance trend analysis grouped by date
- 🎯 **Failure Analysis**: Identify most common failing tasks and error patterns
- 🌍 **Global Statistics**: Cumulative statistics across sessions

### 🔍 Statistics Commands

```bash
# View statistics summary
kdeploy stats summary

# View deployment statistics
kdeploy stats deployments

# View task statistics
kdeploy stats tasks

# View failure statistics
kdeploy stats failures

# View performance trends
kdeploy stats trends

# View global statistics
kdeploy stats global

# Export statistics data
kdeploy stats export --export monthly_report.json

# Clear statistics data
kdeploy stats clear

# Specify time range (days)
kdeploy stats summary --days 7

# JSON format output
kdeploy stats tasks --format json
```

### 📊 Statistics Output Example

```bash
kdeploy stats summary

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

## 🔧 Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check SSH connection
   ssh -vvv user@hostname

   # Verify keys
   ssh-add -l
   ```

2. **Permission Issues**
   ```ruby
   # Use sudo for commands
   run 'sudo systemctl restart nginx'

   # Check file permissions
   run 'ls -la {{deploy_to}}'
   ```

3. **Timeout Issues**
   ```ruby
   # Increase timeout
   run 'long_command', timeout: 300

   # Or set in configuration file
   command_timeout: 600
   ```

### Debugging Tips

```bash
# Verbose output mode
kdeploy deploy script.rb --verbose

# Dry run mode
kdeploy deploy script.rb --dry-run

# View configuration
kdeploy config

# Validate script
kdeploy validate script.rb

# View logs
tail -f kdeploy.log
```

## 🤝 Contributing

We welcome community contributions! Please follow these guidelines:

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Project Homepage](https://github.com/kevin197011/kdeploy)
- [Documentation](https://github.com/kevin197011/kdeploy/wiki)
- [Issue Tracker](https://github.com/kevin197011/kdeploy/issues)
- [Release Notes](https://github.com/kevin197011/kdeploy/releases)

## 💬 Community Support

- GitHub Issues: [Report Issues](https://github.com/kevin197011/kdeploy/issues)
- GitHub Discussions: [Community Discussions](https://github.com/kevin197011/kdeploy/discussions)

---

**Kdeploy** - Making deployment simple and powerful 🚀
