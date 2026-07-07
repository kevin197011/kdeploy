# frozen_string_literal: true

# Docker Lab — 覆盖 REQUIREMENTS.md 主机/角色/模块化 DSL
# 在 runner 容器内执行：kdeploy execute deploy.rb <task>

KEY = '/keys/id_rsa'

inventory do
  # FR-DSL-01: 密钥 + sudo
  host 'ubuntu-web01', user: 'kdeploy', ip: 'ubuntu-web01', key: KEY, use_sudo: true
  host 'ubuntu-web02', user: 'kdeploy', ip: 'ubuntu-web02', key: KEY, use_sudo: true
  host 'rocky-db01',   user: 'kdeploy', ip: 'rocky-db01',   key: KEY, use_sudo: true
  # FR-DSL-01: 密码认证
  host 'debian-pw01',  user: 'kdeploy', ip: 'debian-pw01',  password: 'kdeploy', use_sudo: true
end

role :web, %w[ubuntu-web01 ubuntu-web02]
role :db,  %w[rocky-db01]
role :all, %w[ubuntu-web01 ubuntu-web02 rocky-db01 debian-pw01]

include_tasks 'tasks/smoke.rb'
include_tasks 'tasks/primitives.rb', roles: :web
include_tasks 'tasks/resources_apt.rb', roles: :web
include_tasks 'tasks/resources_yum.rb', roles: :db
include_tasks 'tasks/sync_lab.rb', roles: :web
include_tasks 'tasks/targeting.rb'

# FR-DSL-04: assign_task 事后改定位
assign_task :assigned_echo, on: %w[ubuntu-web02]
