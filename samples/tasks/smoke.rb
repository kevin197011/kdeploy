# frozen_string_literal: true

task :smoke do
  run 'echo smoke && uname -a && id'
end

task :smoke_password, on: %w[web02-pw] do
  run 'echo password-auth-ok && whoami'
end

task :dry_run_all_syntax do
  package 'nginx'
  directory '/tmp/kdeploy-lab', mode: '0755'
  template '/tmp/kdeploy-lab/nginx.conf',
           source: './config/nginx.conf.erb',
           variables: { domain_name: 'lab.local', port: 8080, worker_processes: 2, worker_connections: 1024 }
  file '/tmp/kdeploy-lab/app.conf', source: './config/app.conf'
  upload './config/app.yml', '/tmp/kdeploy-lab/app.yml'
  upload_template './config/marker.erb', '/tmp/kdeploy-lab/marker.txt', { role: 'web', env: 'vagrant' }
  sync './app', '/tmp/kdeploy-lab/app', ignore: ['.git'], delete: true, fast: true
  service 'nginx', action: %i[enable restart]
  run 'nginx -t || true', sudo: true
end
