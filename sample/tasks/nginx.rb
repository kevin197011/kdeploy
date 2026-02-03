# frozen_string_literal: true

# ============================================================================
# Nginx Deployment Tasks (Chef-style resource DSL)
# ============================================================================

# Install nginx on web servers
task :install_nginx do
  package 'nginx'
  service 'nginx', action: %i[enable start]
end

# Configure nginx
task :configure_nginx do
  run 'cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup || true', sudo: true
  directory '/etc/nginx/conf.d'
  template '/etc/nginx/nginx.conf',
           source: './config/nginx.conf.erb',
           variables: {
             domain_name: 'example.com',
             port: 3000,
             worker_processes: 4,
             worker_connections: 2048
           }
  file '/etc/nginx/conf.d/app.conf', source: './config/app.conf'
  run 'nginx -t', sudo: true
  service 'nginx', action: :reload
end

# Deploy web application (install + configure + start)
task :deploy_web do
  package 'nginx'
  directory '/etc/nginx/conf.d'
  run 'cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup || true', sudo: true
  template '/etc/nginx/nginx.conf',
           source: './config/nginx.conf.erb',
           variables: {
             domain_name: 'example.com',
             port: 3000,
             worker_processes: 4,
             worker_connections: 2048
           }
  file '/etc/nginx/conf.d/app.conf', source: './config/app.conf'
  run 'nginx -t', sudo: true
  service 'nginx', action: %i[enable restart]
end

# Start nginx service
task :start_nginx do
  service 'nginx', action: :start
end

# Stop nginx service
task :stop_nginx do
  service 'nginx', action: :stop
end

# Restart nginx service
task :restart_nginx do
  service 'nginx', action: :restart
  run 'sleep 2'
  run 'systemctl status nginx --no-pager', sudo: true
end

# Check nginx status
task :status_nginx do
  run <<~SHELL
    echo "=== Nginx Service Status ==="
    sudo systemctl status nginx --no-pager || true
    echo ""
    echo "=== Nginx Process ==="
    ps aux | grep nginx | grep -v grep || echo "No nginx process found"
    echo ""
    echo "=== Nginx Port Check ==="
    netstat -tlnp 2>/dev/null | grep 80 || ss -tlnp 2>/dev/null | grep 80 || echo "Port 80 not listening"
  SHELL
end
