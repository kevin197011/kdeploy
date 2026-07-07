# frozen_string_literal: true

task :resources_apt do
  package 'nginx'

  directory '/etc/nginx/conf.d', mode: '0755'

  run 'cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.kdeploy-bak || true', sudo: true

  template '/etc/nginx/nginx.conf',
           source: './config/nginx.conf.erb',
           variables: {
             domain_name: 'lab.local',
             port: 8080,
             worker_processes: 2,
             worker_connections: 1024
           }

  file '/etc/nginx/conf.d/kdeploy-lab.conf', source: './config/app.conf'

  run 'nginx -t', sudo: true
  service 'nginx', action: %i[enable restart]
end
