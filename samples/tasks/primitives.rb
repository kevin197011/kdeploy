# frozen_string_literal: true

task :primitives do
  run 'mkdir -p /tmp/kdeploy-lab/primitives', sudo: true

  upload './config/app.conf', '/tmp/kdeploy-lab/primitives/app.conf'

  upload_template './config/marker.erb',
                  '/tmp/kdeploy-lab/primitives/marker.txt',
                  { role: 'web', env: 'vagrant' }

  run <<~SHELL
    test -f /tmp/kdeploy-lab/primitives/app.conf
    test -f /tmp/kdeploy-lab/primitives/marker.txt
    grep -q 'vagrant' /tmp/kdeploy-lab/primitives/marker.txt
    echo primitives-ok
  SHELL
end
