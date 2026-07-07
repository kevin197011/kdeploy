# frozen_string_literal: true

task :resources_yum do
  package 'tar', platform: :yum

  run <<~SHELL
    tar --version | head -1
    curl --version | head -1
    echo yum-ok
  SHELL
end
