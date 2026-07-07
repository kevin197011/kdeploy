# frozen_string_literal: true

# FR-DSL-05 sync：ignore / exclude / delete / fast

task :sync_lab do
  sync './app', '/var/www/kdeploy-lab/app',
       ignore: ['.git', '*.log', '*.tmp'],
       delete: true,
       fast: true,
       parallel: 2

  sync './config', '/etc/kdeploy-lab',
       exclude: ['*.example', '*.bak', 'nginx.conf.erb'],
       delete: false

  sync './static', '/var/www/kdeploy-lab/static',
       ignore: ['*.map'],
       delete: true

  run <<~SHELL
    test -f /var/www/kdeploy-lab/app/index.html
    test -f /etc/kdeploy-lab/app.yml
    test ! -f /etc/kdeploy-lab/app.yml.example
    test -f /var/www/kdeploy-lab/static/style.css
    echo sync-ok
  SHELL
end

task :sync_advanced do
  sync './project', '/opt/kdeploy-lab/project',
       ignore: ['.git', 'node_modules', '*.log', 'dist/', '.env.local'],
       delete: true

  run 'find /opt/kdeploy-lab/project -type f | head -5', sudo: true
end
