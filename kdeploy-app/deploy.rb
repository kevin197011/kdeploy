# frozen_string_literal: true

# 设置日志级别
set 'log_level', 'info'

# 加载主机清单
inventory 'inventory.yml'

# 设置模板目录
template_dir 'templates'

# 定义变量
set 'application', 'myapp'
set 'version', '1.0.0'
set 'deploy_user', 'root'

# 本地命令
local 'echo "=== Starting deployment ==="'

# 准备目录
task 'prepare', on: :app do
  run 'mkdir -p {{deploy_path}}'
  run 'chown -R {{deploy_user}}:{{deploy_user}} {{deploy_path}}'
end

# 配置 Nginx
task 'setup_nginx', on: :nginx do
  upload_template 'nginx.conf.erb', '/etc/nginx/conf.d/{{app_name}}.conf'
  run 'nginx -t'
  run 'systemctl reload nginx'
end

# 配置应用服务
task 'setup_service', on: :app do
  upload_template 'app.service.erb', '/etc/systemd/system/{{app_name}}.service'
  run 'systemctl daemon-reload'
  run 'systemctl enable {{app_name}}'
  run 'systemctl restart {{app_name}}'
end

# 检查服务状态
task 'check', on: %i[nginx app] do
  run 'systemctl status nginx'
  run 'systemctl status {{app_name}}'
  run 'curl -s http://localhost:{{nginx_port}}'
end

# 本地命令
local 'echo "=== Deployment complete ==="'
