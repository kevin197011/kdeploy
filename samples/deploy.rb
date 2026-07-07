# frozen_string_literal: true

# Vagrant 全功能实测 — 在 samples/ 目录执行：
#   vagrant up --provider avf   # M 系列 Mac 推荐
#   ./test.sh

require_relative 'vagrant_hosts'

base = __dir__
web01_port, web01_key = VagrantHosts.resolve('web01', base_dir: base, fallback_port: 2200,
                                                      fallback_key: '.vagrant/machines/web01/virtualbox/private_key')
web02_port, web02_key = VagrantHosts.resolve('web02', base_dir: base, fallback_port: 2201,
                                                      fallback_key: '.vagrant/machines/web02/virtualbox/private_key')

inventory do
  host 'web01', user: 'vagrant', ip: '127.0.0.1', port: web01_port, key: web01_key, use_sudo: true
  host 'web02', user: 'vagrant', ip: '127.0.0.1', port: web02_port, key: web02_key, use_sudo: true
  host 'web02-pw', user: 'kdeploy', ip: '127.0.0.1', port: web02_port, password: 'kdeploy', use_sudo: true
end

role :web, %w[web01]
role :db,  %w[web02]
role :all, %w[web01 web02 web02-pw]

include_tasks 'tasks/smoke.rb'
include_tasks 'tasks/primitives.rb', roles: :web
include_tasks 'tasks/resources_apt.rb', roles: :web
include_tasks 'tasks/resources_yum.rb', roles: :db
include_tasks 'tasks/sync_lab.rb', roles: :web
include_tasks 'tasks/targeting.rb'

assign_task :assigned_echo, on: %w[web02]

# 演示任务（默认未纳入全量实测）：
# include_tasks 'tasks/nginx.rb', roles: :web
# include_tasks 'tasks/node_exporter.rb', roles: :web
# include_tasks 'tasks/system.rb', roles: :web
# include_tasks 'tasks/sync.rb', roles: :web
