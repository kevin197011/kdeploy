# frozen_string_literal: true

# Heredoc and Template deployment example for Kdeploy
# This script demonstrates heredoc syntax and ERB template usage

# Configure pipeline name
pipeline 'Heredoc and Template Deployment Example'

# Load hosts from inventory file
inventory 'sample_inventory.yml'

# Set template directory
template_dir 'templates'

# Set global variables
set :application, 'webapp'
set :deploy_to, '/opt/webapp'
set :repo_url, 'https://github.com/company/webapp.git'
set :branch, 'main'
set :app_port, 3000
set :environment, 'production'

# System preparation using heredoc syntax
task 'system_prep', on: :webservers do
  run <<~SHELL
    # Update system packages
    sudo apt-get update -y
    sudo apt-get upgrade -y

    # Install essential packages
    sudo apt-get install -y \\
      curl \\
      wget \\
      git \\
      build-essential \\
      nginx

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Verify installations
    echo "Node.js version: $(node --version)"
    echo "NPM version: $(npm --version)"
    echo "Nginx version: $(nginx -v)"
  SHELL
end

# Deploy application using heredoc
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

    echo "Application deployed successfully!"
  DEPLOYMENT
end

# Configure nginx using ERB template
task 'configure_nginx', on: :webservers do
  # Upload nginx configuration from template
  upload_template 'nginx.conf', '/tmp/webapp_nginx.conf',
                  variables: {
                    server_name: '{{hostname}}',
                    upstream_port: 3000
                  }

  run <<~NGINX_SETUP
    # Backup existing configuration
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup || true

    # Install new configuration
    sudo mv /tmp/webapp_nginx.conf /etc/nginx/sites-available/{{application}}
    sudo ln -sf /etc/nginx/sites-available/{{application}} /etc/nginx/sites-enabled/

    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test and reload nginx
    sudo nginx -t
    sudo systemctl reload nginx
    sudo systemctl enable nginx
  NGINX_SETUP
end

# Setup systemd service using template
task 'setup_service', on: :webservers do
  # Upload systemd service file from template
  upload_template 'app.service', '/tmp/{{application}}.service',
                  variables: {
                    description: 'Web Application Service',
                    exec_start: 'node server.js'
                  }

  run <<~SERVICE_SETUP
    # Install systemd service
    sudo mv /tmp/{{application}}.service /etc/systemd/system/

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable {{application}}
    sudo systemctl start {{application}}

    # Check service status
    sudo systemctl status {{application}} --no-pager
  SERVICE_SETUP
end

# Database setup and backup using template
task 'setup_database', on: :databases do
  run <<~DB_SETUP
    # Install PostgreSQL
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib

    # Start and enable PostgreSQL
    sudo systemctl start postgresql
    sudo systemctl enable postgresql

    # Create application database
    sudo -u postgres createdb {{application}}_{{environment}} || echo "Database already exists"

    # Set up database user (if needed)
    sudo -u postgres psql -c "CREATE USER {{application}}_user WITH PASSWORD 'secure_password';" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE {{application}}_{{environment}} TO {{application}}_user;" || true
  DB_SETUP

  # Upload backup script from template
  upload_template 'backup.sh', '/opt/{{application}}/backup.sh',
                  variables: {
                    retention_days: 7,
                    backup_path: '/backup/{{application}}'
                  }

  run <<~BACKUP_SETUP
    # Make backup script executable
    chmod +x /opt/{{application}}/backup.sh

    # Create backup directory
    sudo mkdir -p /backup/{{application}}
    sudo chown {{user}}:{{user}} /backup/{{application}}

    # Add to crontab for daily backups
    (crontab -l 2>/dev/null || true; echo "0 2 * * * /opt/{{application}}/backup.sh") | crontab -

    echo "Database backup scheduled for 2 AM daily"
  BACKUP_SETUP
end

# Health check with retry logic
task 'health_check', on: :webservers do
  run <<~HEALTH_CHECK
    echo "Performing health check on {{hostname}}..."

    # Wait for service to start
    for i in {1..30}; do
      if curl -f http://localhost:{{app_port}}/health >/dev/null 2>&1; then
        echo "✅ Health check passed on attempt $i"
        break
      else
        echo "⏳ Health check failed, retrying in 2 seconds... (attempt $i/30)"
        sleep 2
        if [ $i -eq 30 ]; then
          echo "❌ Health check failed after 30 attempts"
          exit 1
        fi
      fi
    done

    # Additional checks
    echo "Checking service status..."
    sudo systemctl is-active {{application}} || exit 1

    echo "Checking nginx status..."
    sudo systemctl is-active nginx || exit 1

    echo "All health checks passed! 🎉"
  HEALTH_CHECK
end

# Cleanup and optimization
task 'cleanup', on: :production do
  run <<~CLEANUP
    echo "Performing cleanup on {{hostname}}..."

    # Clean package cache
    sudo apt-get autoremove -y
    sudo apt-get autoclean

    # Clean application logs older than 7 days
    find {{deploy_to}}/logs -name "*.log" -mtime +7 -delete 2>/dev/null || true

    # Clean node_modules cache
    find {{deploy_to}}/node_modules -name '.cache' -type d -exec rm -rf {} + 2>/dev/null || true

    # Clean npm cache
    npm cache clean --force 2>/dev/null || true

    # Show disk usage
    echo "Disk usage after cleanup:"
    df -h / | tail -1

    echo "Cleanup completed!"
  CLEANUP
end

# Rollback task using template-generated script
task 'rollback', on: :webservers do
  # First, render and execute a rollback script template
  run_template 'rollback.sh',
               variables: {
                 rollback_steps: 1,
                 backup_before_rollback: true
               },
               name: 'execute_rollback_script'

  # Additional rollback steps
  run <<~ROLLBACK_STEPS
    echo "Performing additional rollback steps..."

    # Restart services
    sudo systemctl restart {{application}}
    sudo systemctl restart nginx

    # Verify rollback
    sleep 5
    curl -f http://localhost:{{app_port}}/health || exit 1

    echo "Rollback completed successfully!"
  ROLLBACK_STEPS
end

# Conditional deployment based on environment
if ENV['DEPLOY_ENV'] == 'production'
  task 'production_security', on: :production do
    run <<~SECURITY
      echo "Applying production security settings..."

      # Firewall configuration
      sudo ufw --force enable
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow ssh
      sudo ufw allow 80/tcp
      sudo ufw allow 443/tcp

      # Fail2ban setup
      sudo apt-get install -y fail2ban
      sudo systemctl enable fail2ban
      sudo systemctl start fail2ban

      echo "Production security applied!"
    SECURITY
  end
end
