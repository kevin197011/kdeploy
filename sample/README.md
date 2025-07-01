# Deployment Project

This is a deployment project created with Kdeploy.

## 📁 Structure

```
.
├── deploy.rb           # Deployment tasks
├── config/            # Configuration files
│   ├── nginx.conf.erb # Nginx configuration template
│   └── app.conf      # Static configuration
└── README.md         # This file
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

## 🚀 Usage

### Task Execution

```bash
# Execute all tasks in the file
kdeploy execute deploy.rb

# Execute a specific task
kdeploy execute deploy.rb deploy_web

# Execute with dry run (preview mode)
kdeploy execute deploy.rb --dry-run

# Execute on specific hosts
kdeploy execute deploy.rb --limit web01,web02

# Execute with custom parallel count
kdeploy execute deploy.rb --parallel 5
```

When executing without specifying a task name (`kdeploy execute deploy.rb`), Kdeploy will:
1. Execute all defined tasks in the file
2. Run tasks in the order they were defined
3. Show task name before each task execution
4. Display color-coded output for better readability:
    - 🟢 Green: Normal output and success messages
    - 🔴 Red: Errors and failure messages
    - 🟡 Yellow: Warnings and notices

### Available Tasks

- **deploy_web**: Deploy and configure Nginx web servers
  ```bash
  kdeploy execute deploy.rb deploy_web
  ```

- **backup_db**: Backup database to S3
  ```bash
  kdeploy execute deploy.rb backup_db
  ```

- **maintenance**: Run maintenance on specific host
  ```bash
  kdeploy execute deploy.rb maintenance
  ```

- **update**: Update all hosts
  ```bash
  kdeploy execute deploy.rb update
  ```
