# frozen_string_literal: true

# Define hosts
host 'web01', user: 'root', ip: '157.245.153.4', key: '~/.ssh/id_rsa'

# Define roles
role :web, %w[web01]

# Define deployment task for web servers
task :deploy_web, roles: :web do
  run 'uptime'

  upload_template './config/nginx.conf.erb', '/tmp/nginx.conf',
                  domain_name: 'example.com',
                  port: 3000,
                  worker_processes: 4,
                  worker_connections: 2048

  upload './config/app.conf', '/tmp/app.conf'

  run 'ls /tmp'
end
