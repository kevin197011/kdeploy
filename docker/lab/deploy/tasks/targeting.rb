# frozen_string_literal: true

# FR-DSL-03 定位：on / roles / assign_task

task :target_web01, on: %w[ubuntu-web01] do
  run 'echo target=ubuntu-web01 && hostname'
end

task :target_web_role, roles: :web do
  run 'echo target=web-role && hostname'
end

task :target_db_role, roles: :db do
  run 'echo target=rocky-db && cat /etc/os-release | head -1'
end

# 定义时不带 on/roles，由 deploy.rb assign_task 指定 ubuntu-web02
task :assigned_echo do
  run 'echo assigned-to-web02 && hostname'
end
