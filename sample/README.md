# Kdeploy Sample Project - Nginx Deployment

This is a sample deployment project demonstrating Kdeploy's capabilities with Nginx installation and configuration using Vagrant VMs for testing.

## 📁 Structure

```
.
├── Vagrantfile        # Vagrant configuration for test VMs
├── deploy.rb          # Deployment tasks
├── config/            # Configuration files
│   ├── nginx.conf.erb # Nginx configuration template
│   └── app.conf       # Static configuration
└── README.md          # This file
```

## 🔧 Configuration Templates

The project uses ERB templates for dynamic configuration. For example, in `nginx.conf.erb`:

```erb
worker_processes <%= worker_processes %>;
server_name <%= domain_name %>;
```

Variables are passed when uploading the template:

```ruby
upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
  domain_name: "example.com",
  worker_processes: 4
```

## 🚀 Quick Start with Vagrant

### Prerequisites

- [Vagrant](https://www.vagrantup.com/) installed
- [VirtualBox](https://www.virtualbox.org/) or another Vagrant provider
- [Kdeploy](https://rubygems.org/gems/kdeploy) gem installed

### Step 1: Start Vagrant VMs

```bash
# Start the VMs (this will download the Ubuntu box on first run)
vagrant up

# Check VM status
vagrant status

# SSH into a VM to verify it's working
vagrant ssh web01
```

### Step 2: Verify SSH Configuration

Vagrant automatically generates SSH keys and sets up port forwarding for each VM. The `deploy.rb` is configured to use:
- **web01**: `127.0.0.1:2200` (Vagrant port forwarding)
- **web02**: `127.0.0.1:2201` (Vagrant port forwarding)
- SSH keys: `.vagrant/machines/{vm_name}/virtualbox/private_key`

These are created automatically when you run `vagrant up`. You can check the SSH configuration with:
```bash
vagrant ssh-config web01
vagrant ssh-config web02
```

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
