# frozen_string_literal: true

# FR-CLI-03 / FR-EXEC-02: 连通性与 dry-run 覆盖

task :smoke do
  run 'echo smoke && uname -a && id'
end

task :smoke_password, on: %w[debian-pw01] do
  run 'echo password-auth-ok && whoami'
end

# 含 service 资源（建议 --dry-run 验证编译；容器无 systemd PID1）
task :dry_run_all_syntax do
  package 'nginx'
  directory '/tmp/kdeploy-lab', mode: '0755'
  template '/tmp/kdeploy-lab/nginx.conf',
           source: './config/nginx.conf.erb',
           variables: { domain_name: 'lab.local', port: 8080, worker_processes: 2, worker_connections: 1024 }
  file '/tmp/kdeploy-lab/app.conf', source: './config/app.conf'
  upload './config/app.yml', '/tmp/kdeploy-lab/app.yml'
  upload_template './config/marker.erb', '/tmp/kdeploy-lab/marker.txt', { role: 'web', env: 'lab' }
  sync './app', '/tmp/kdeploy-lab/app', ignore: ['.git'], delete: true, fast: true
  service 'nginx', action: %i[enable restart]
  run 'nginx -t || true', sudo: true
end
