# frozen_string_literal: true

# ============================================================================
# Directory Synchronization Tasks
# ============================================================================
# These tasks demonstrate the directory synchronization feature of Kdeploy
# which allows you to sync entire directory trees with file filtering support

# Sync application directory to remote server
# This example syncs a local app directory to /var/www/app on remote servers
task :sync_app do
  # Sync application code, ignoring development and temporary files
  sync './app', '/var/www/app',
       ignore: [
         '.git',           # Git directory
         '*.log',          # Log files
         '*.tmp',          # Temporary files
         'node_modules',   # Node.js dependencies (if using Node.js)
         '.env.local',     # Local environment files
         '*.swp',          # Vim swap files
         '*.swo',          # Vim swap files
         '.DS_Store'       # macOS system files
       ],
       delete: true        # Delete files on remote that don't exist locally

  # Restart application service after sync
  run 'sudo systemctl restart app || echo "Service restart skipped (service may not exist)"'
end

# Sync configuration files directory
# This example syncs configuration files while excluding example and backup files
task :sync_config do
  sync './config', '/etc/app',
       exclude: [
         '*.example',      # Example configuration files
         '*.bak',          # Backup files
         '*.backup',       # Backup files
         '*.orig',         # Original files
         '.env.local'      # Local environment files
       ],
       delete: false       # Don't delete extra files (safer for configs)

  # Reload application to apply new configuration
  run 'sudo systemctl reload app || echo "Service reload skipped (service may not exist)"'
end

# Sync static assets (HTML, CSS, JS, images)
# This example syncs static files while ignoring source maps and development files
task :sync_static do
  sync './static', '/var/www/static',
       ignore: [
         '*.map',          # Source map files
         '*.min.map',      # Minified source maps
         '.DS_Store',      # macOS system files
         'Thumbs.db',      # Windows thumbnail files
         '*.scss',         # SASS source files (if you only want compiled CSS)
         '*.less'          # LESS source files (if you only want compiled CSS)
       ],
       delete: true        # Delete old static files

  # Set proper permissions for static files
  run 'sudo chown -R www-data:www-data /var/www/static || echo "Permission change skipped"'
  run 'sudo chmod -R 755 /var/www/static || echo "Permission change skipped"'
end

# Full deployment with directory synchronization
# This task combines multiple sync operations for a complete deployment
task :deploy_full do
  # Step 1: Sync application code
  sync './app', '/var/www/app',
       ignore: ['.git', '*.log', '*.tmp', 'node_modules', '.env.local'],
       delete: true

  # Step 2: Sync configuration files
  sync './config', '/etc/app',
       exclude: ['*.example', '*.bak', '.env.local'],
       delete: false

  # Step 3: Sync static assets
  sync './static', '/var/www/static',
       ignore: ['*.map', '.DS_Store'],
       delete: true

  # Step 4: Set permissions
  run <<~SHELL
    sudo chown -R www-data:www-data /var/www/app || true
    sudo chmod -R 755 /var/www/app || true
    sudo chown -R www-data:www-data /var/www/static || true
    sudo chmod -R 755 /var/www/static || true
  SHELL

  # Step 5: Restart services
  run <<~SHELL
    sudo systemctl restart app || echo "App service restart skipped"
    sudo systemctl reload nginx || echo "Nginx reload skipped"
  SHELL

  # Step 6: Verify deployment
  run <<~SHELL
    echo "=== Deployment Verification ==="
    echo "Application directory:"
    ls -la /var/www/app | head -10 || true
    echo ""
    echo "Configuration directory:"
    ls -la /etc/app | head -10 || true
    echo ""
    echo "Service status:"
    sudo systemctl status app --no-pager || echo "App service not found"
  SHELL
end

# Sync with advanced filtering
# This example demonstrates more complex ignore patterns
task :sync_advanced do
  sync './project', '/opt/project',
       ignore: [
         # Version control
         '.git',
         '.svn',
         '.hg',
         # Build artifacts
         'dist/',
         'build/',
         'target/',
         '*.o',
         '*.a',
         '*.so',
         # Dependencies
         'node_modules/',
         'vendor/',
         'venv/',
         '.bundle/',
         # IDE and editor files
         '.idea/',
         '.vscode/',
         '*.swp',
         '*.swo',
         '*.sublime-*',
         # OS files
         '.DS_Store',
         'Thumbs.db',
         '.Trash-*',
         # Logs and temporary files
         '*.log',
         '*.tmp',
         '*.cache',
         'tmp/',
         # Environment files
         '.env*',
         '!.env.example'
       ],
       delete: true

  # Post-sync operations
  run <<~SHELL
    # Set ownership
    sudo chown -R app:app /opt/project || true

    # Set permissions
    sudo find /opt/project -type d -exec chmod 755 {} \\;
    sudo find /opt/project -type f -exec chmod 644 {} \\;

    # Make scripts executable
    sudo find /opt/project -name "*.sh" -exec chmod +x {} \\;
  SHELL
end
