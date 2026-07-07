# frozen_string_literal: true

# FR-DSL-05 原语：run / upload / upload_template

task :primitives do
  run 'mkdir -p /tmp/kdeploy-lab/primitives', sudo: true

  upload './config/app.conf', '/tmp/kdeploy-lab/primitives/app.conf'

  upload_template './config/marker.erb',
                  '/tmp/kdeploy-lab/primitives/marker.txt',
                  { role: 'web', env: 'lab' }

  run <<~SHELL
    test -f /tmp/kdeploy-lab/primitives/app.conf
    test -f /tmp/kdeploy-lab/primitives/marker.txt
    grep -q 'lab' /tmp/kdeploy-lab/primitives/marker.txt
    echo primitives-ok
  SHELL
end
