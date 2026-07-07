# Kdeploy Sample Project - Nginx Deployment

This is a sample deployment project demonstrating Kdeploy's capabilities with Nginx installation and configuration using Vagrant VMs for testing.

## 📁 Structure

```
.
├── Vagrantfile        # Vagrant configuration for test VMs
├── deploy.rb          # Main deployment file (hosts, roles, task includes)
├── tasks/             # Task files directory
│   ├── nginx.rb       # Nginx deployment tasks
│   ├── node_exporter.rb # Node Exporter deployment tasks
│   ├── system.rb      # System maintenance tasks
│   └── sync.rb        # Directory synchronization tasks
├── config/            # Configuration files
│   ├── nginx.conf.erb # Nginx configuration template
│   ├── node_exporter.service.erb # Node Exporter systemd unit template
│   ├── app.conf       # Static configuration
│   ├── app.yml        # Application configuration (will be synced)
│   └── app.yml.example # Example config (excluded from sync)
├── app/               # Sample application directory (for sync demo)
│   ├── index.html     # Sample HTML file
│   ├── app.rb         # Sample Ruby application
│   └── README.md      # App directory documentation
├── static/            # Static assets directory (for sync demo)
│   ├── style.css      # CSS file
│   └── app.js         # JavaScript file
└── README.md          # This file
```

## 📋 Task Organization

Tasks are organized into separate files in the `tasks/` directory for better modularity:

- **`tasks/nginx.rb`**: All Nginx-related tasks (install, configure, deploy, start, stop, restart, status)
- **`tasks/node_exporter.rb`**: Node Exporter deployment and management tasks
- **`tasks/system.rb`**: System maintenance tasks (update, maintenance)
- **`tasks/sync.rb`**: Directory synchronization tasks (sync_app, sync_config, sync_static, deploy_full)

In `deploy.rb`, you can simply use `include_tasks` to load task files and automatically assign all tasks to roles:

```ruby
# Include task files and assign all tasks to roles in one line
include_tasks 'tasks/nginx.rb', roles: :web
include_tasks 'tasks/node_exporter.rb', roles: :web
include_tasks 'tasks/system.rb', roles: :web

# Or comment out to exclude specific task groups
# include_tasks 'tasks/node_exporter.rb', roles: :web
```

**Key Points**:
- Task files (`tasks/*.rb`) define tasks **without** specifying roles
- `include_tasks` automatically assigns all tasks in the file to the specified role
- Tasks that already have `on:` or `roles:` defined in the task file will not be overridden
- This separation allows you to reuse task files across different projects with different role assignments

This modular approach allows you to:
- Organize tasks by service or functionality
- Easily enable/disable task groups
- Share task files across multiple deployment projects
- Maintain cleaner, more focused code

## 🔧 Configuration Templates

The project uses ERB templates for dynamic configuration. For example, in `nginx.conf.erb`:

```erb
worker_processes <%= worker_processes %>;
server_name <%= domain_name %>;
```

Variables are passed when uploading the template (Chef-style resource DSL):

```ruby
template "/etc/nginx/nginx.conf",
  source: "./config/nginx.conf.erb",
  variables: { domain_name: "example.com", worker_processes: 4 }
```

## 🚀 Quick Start — 全功能实测（两台小配置 VM）

| VM | 发行版 | 内存 | 用途 |
|----|--------|------|------|
| `web01` | Ubuntu 24.04 ARM64 | 768MB | apt、`package`、nginx、`service`、sync |
| `web02` | Rocky 9 ARM64 | 512MB | yum；同机 `kdeploy` 用户测密码 SSH |

### M 系列 Mac（推荐 AVF 原生虚拟化）

VirtualBox 在 Apple Silicon 上 SSH 常不稳定，请用 **Apple Virtualization Framework**：

```bash
vagrant plugin install vagrant-provider-avf
vagrant box add sodini-io/ubuntu-24.04-arm64 --provider avf
vagrant box add sodini-io/rocky-9-arm64 --provider avf

cd samples
./test.sh                    # 自动选 --provider avf
# 或
vagrant up --provider avf
./scripts/run-tests.sh
```

镜像来源：[sodini-io/vagrant-provider-avf](https://github.com/sodini-io/vagrant-provider-avf)（`ubuntu-24.04-arm64` / `rocky-9-arm64`）。

### Intel Mac / Linux（VirtualBox）

```bash
cd samples
vagrant up --provider virtualbox
./scripts/run-tests.sh
```

Box：`bento/ubuntu-24.04`、`bento/rocky-9`（可加 `vm.box_architecture = 'arm64'` 于 ARM 主机）。

`deploy.rb` 会从 `vagrant ssh-config` 读取实际 SSH 端口与私钥，兼容 AVF / VirtualBox。

### 一键实测

```bash
cd samples
./test.sh
```

单任务：`kdeploy execute deploy.rb smoke --dry-run`

### 实测任务与需求映射

| 任务 | 覆盖 |
|------|------|
| `smoke` / `smoke_password` | 连通性、密钥 + 密码 |
| `dry_run_all_syntax` | 全部资源原语 dry-run |
| `primitives` | `upload`、`upload_template` |
| `resources_apt` | apt `package`、`template`、`file`、`service` |
| `resources_yum` | yum `package` |
| `sync_lab` / `sync_advanced` | `sync` ignore/exclude/delete/fast |
| `target_*` / `assigned_echo` | `on`、`roles`、`assign_task` |
| 脚本层 | `--dry-run`、`--format json`、`--limit`、`--parallel` |

演示任务（`nginx.rb` 等）保留在 `tasks/`，默认未纳入 `deploy.rb`，可手动 `include_tasks`。

---

## 🚀 Quick Start with Vagrant (legacy detail)

### Prerequisites

- [Vagrant](https://www.vagrantup.com/) installed
- [VirtualBox](https://www.virtualbox.org/) or another Vagrant provider
- [Kdeploy](https://rubygems.org/gems/kdeploy) gem installed

### Step 1: Start Vagrant VMs

```bash
vagrant up
vagrant status
vagrant ssh web01
vagrant ssh web02
```

### Step 2: Verify SSH Configuration

Vagrant automatically generates SSH keys and sets up port forwarding for each VM. The `deploy.rb` is configured to use:
- **web01**: `127.0.0.1:2200` (Ubuntu, vagrant key)
- **web02**: `127.0.0.1:2201` (Rocky, vagrant key)
- **web02-pw**: `127.0.0.1:2201` (Rocky, `kdeploy` / `kdeploy` 密码)
- SSH keys: `.vagrant/machines/{vm_name}/virtualbox/private_key`

If you want to use your own SSH key or connect via private network:

1. Copy your public key to the VM:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub vagrant@10.0.0.1
   ```

2. Update `deploy.rb` to use your key:
   ```ruby
   host 'web01', user: 'vagrant', ip: '10.0.0.1', key: '~/.ssh/id_rsa', use_sudo: true
   ```

### Step 3: Test Deployment

```bash
# Preview what will be executed (dry run)
kdeploy execute deploy.rb install_nginx --dry-run

# Install nginx on all web servers
kdeploy execute deploy.rb install_nginx

# Configure nginx
kdeploy execute deploy.rb configure_nginx

# Full deployment (install + configure)
kdeploy execute deploy.rb deploy_web

# Check nginx status
kdeploy execute deploy.rb status_nginx

# Test nginx from host machine
curl http://localhost:8081  # web01
curl http://localhost:8082  # web02
```

## 📋 Available Tasks

### Installation Tasks

- **install_nginx**: Install nginx on web servers
  ```bash
  kdeploy execute deploy.rb install_nginx
  ```

- **configure_nginx**: Configure nginx with templates
  ```bash
  kdeploy execute deploy.rb configure_nginx
  ```

- **deploy_web**: Full deployment (install + configure)
  ```bash
  kdeploy execute deploy.rb deploy_web
  ```

### Service Management Tasks

- **start_nginx**: Start nginx service
  ```bash
  kdeploy execute deploy.rb start_nginx
  ```

- **stop_nginx**: Stop nginx service
  ```bash
  kdeploy execute deploy.rb stop_nginx
  ```

- **restart_nginx**: Restart nginx service
  ```bash
  kdeploy execute deploy.rb restart_nginx
  ```

- **status_nginx**: Check nginx status and process
  ```bash
  kdeploy execute deploy.rb status_nginx
  ```

### Maintenance Tasks

- **maintenance**: Run maintenance on specific host
  ```bash
  kdeploy execute deploy.rb maintenance
  ```

- **update**: Update system packages
  ```bash
  kdeploy execute deploy.rb update
  ```

### Directory Synchronization Tasks

- **sync_app**: Sync application directory to remote server
  ```bash
  kdeploy execute deploy.rb sync_app
  ```
  Syncs `./app` to `/var/www/app` with file filtering

- **sync_config**: Sync configuration files directory
  ```bash
  kdeploy execute deploy.rb sync_config
  ```
  Syncs `./config` to `/etc/app` excluding example and backup files

- **sync_static**: Sync static assets (HTML, CSS, JS, images)
  ```bash
  kdeploy execute deploy.rb sync_static
  ```
  Syncs `./static` to `/var/www/static` with filtering

- **deploy_full**: Full deployment with multiple directory synchronizations
  ```bash
  kdeploy execute deploy.rb deploy_full
  ```
  Combines app, config, and static syncs with post-deployment steps

- **sync_advanced**: Advanced sync with complex filtering patterns
  ```bash
  kdeploy execute deploy.rb sync_advanced
  ```
  Demonstrates advanced ignore patterns for complex projects

## 🎯 Task Execution Options

```bash
# Execute all tasks in the file
kdeploy execute deploy.rb

# Execute a specific task
kdeploy execute deploy.rb deploy_web

# Execute with dry run (preview mode)
kdeploy execute deploy.rb deploy_web --dry-run

# Execute on specific hosts
kdeploy execute deploy.rb deploy_web --limit web01

# Execute with custom parallel count
kdeploy execute deploy.rb deploy_web --parallel 2
```

## 🔐 Sudo Support

This project uses the `use_sudo: true` option in host configuration, which means all commands automatically use sudo. You can also use sudo at the command level:

```ruby
# Command-level sudo
run "systemctl restart nginx", sudo: true
```

## 📁 Directory Synchronization

Kdeploy supports directory synchronization with file filtering. The sample project includes several example directories:

- **`app/`**: Sample application directory with HTML and Ruby files
- **`static/`**: Static assets (CSS, JavaScript)
- **`config/`**: Configuration files (including example files that are excluded)

### Example: Sync Application Directory

```ruby
sync './app', '/var/www/app',
     ignore: ['.git', '*.log', '*.tmp', 'node_modules', '.env.local'],
     delete: true
```

This will:
- Recursively sync all files from `./app` to `/var/www/app`
- Ignore files matching the specified patterns
- Delete files on remote that don't exist locally (when `delete: true`)

### Ignore Patterns

The sync command supports .gitignore-style patterns:
- `*.log` - Match all .log files
- `node_modules` - Match node_modules directory
- `**/*.tmp` - Recursively match all .tmp files
- `.git` - Match .git directory

See `tasks/sync.rb` for more examples of directory synchronization.

## 🧪 Testing Workflow

1. **Start VMs**: `vagrant up`
2. **Test Connection**: `kdeploy execute deploy.rb status_nginx --dry-run`
3. **Install Nginx**: `kdeploy execute deploy.rb install_nginx`
4. **Configure Nginx**: `kdeploy execute deploy.rb configure_nginx`
5. **Verify**: `curl http://localhost:8081` (web01) or `curl http://localhost:8082` (web02)
6. **Check Status**: `kdeploy execute deploy.rb status_nginx`

## 🧹 Cleanup

```bash
# Stop VMs
vagrant halt

# Destroy VMs (removes all data)
vagrant destroy
```

## 📝 Notes

- **Network Configuration**:
  - Private network IPs: `10.0.0.1` (web01) and `10.0.0.2` (web02)
  - SSH access via port forwarding: `127.0.0.1:2200` (web01) and `127.0.0.1:2201` (web02)
  - HTTP port forwarding: VM port 80 → host `8081` (web01) and `8082` (web02)
- **SSH Configuration**:
  - Uses Vagrant's automatically generated SSH keys
  - Keys location: `.vagrant/machines/{vm_name}/virtualbox/private_key`
  - The `vagrant` user has passwordless sudo configured
- **Deployment**:
  - All tasks use the `use_sudo: true` option for automatic sudo execution
