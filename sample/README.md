# Deployment Project

This is a deployment project created with Kdeploy.

## Structure

```
.
├── deploy.rb           # Deployment tasks
├── config/            # Configuration files
│   ├── nginx.conf.erb # Nginx configuration template
│   └── app.conf      # Static configuration
└── README.md         # This file
```

## Configuration Templates

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

## Usage

```bash
# Show what would be done
kdeploy execute deploy.rb --dry-run

# Deploy to web servers
kdeploy execute deploy.rb deploy_web

# Backup database
kdeploy execute deploy.rb backup_db

# Run maintenance on web01
kdeploy execute deploy.rb maintenance

# Update all hosts
kdeploy execute deploy.rb update

# Deploy to specific hosts
kdeploy execute deploy.rb deploy_web --limit web01,web02
```
