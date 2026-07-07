# frozen_string_literal: true

task :target_web01, on: %w[web01] do
  run 'echo target=web01 && hostname'
end

task :target_web_role, roles: :web do
  run 'echo target=web-role && hostname'
end

task :target_db_role, roles: :db do
  run 'echo target=rocky-db && cat /etc/os-release | head -1'
end

task :assigned_echo do
  run 'echo assigned-to-web02 && hostname'
end
