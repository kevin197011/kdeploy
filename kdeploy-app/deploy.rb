# frozen_string_literal: true

# 设置日志级别
set 'log_level', 'info'

# 加载主机清单
inventory 'inventory.yml'

# 设置模板目录
template_dir 'templates'

# 本地命令
local 'echo "=== Starting deployment ==="'

# 系统健康检查
task 'system_health', on: :all do
  run 'echo "=== System Health for {{hostname}} ==="'
  run 'uptime'
  run 'df -h'
  run 'free -h'
end

# 准备目录
task 'prepare', on: :web do
  run 'mkdir -p {{deploy_to}}', ignore_errors: true
  run 'chown -R {{user}}:{{user}} {{deploy_to}}', ignore_errors: true
end

# 配置 Nginx
task 'setup_nginx', on: :web do
  run 'apt-get update && apt-get install -y nginx', ignore_errors: true
  upload_template 'nginx.conf.erb', '/etc/nginx/conf.d/{{application}}.conf'
  run 'nginx -t'
  run 'systemctl enable nginx'
  run 'systemctl reload nginx'
end

# 配置应用服务
task 'setup_service', on: :app do
  upload_template 'app.service.erb', '/etc/systemd/system/{{application}}.service'
  run 'systemctl daemon-reload'
  run 'systemctl enable {{application}}'
  run 'systemctl restart {{application}}'
end

# 健康检查
task 'health_check', on: %i[web app] do
  run 'systemctl status nginx', ignore_errors: true
  run 'systemctl status {{application}}', ignore_errors: true
  run 'curl -f http://localhost:{{nginx_port}}/health || echo "Health check failed"',
      timeout: 10, ignore_errors: true
end

# 完整部署流程
task 'deploy' do
  invoke 'system_health'
  invoke 'prepare'
  invoke 'setup_nginx'
  invoke 'setup_service'
  invoke 'health_check'
end

# 本地命令
local 'echo "=== Deployment complete ==="'
