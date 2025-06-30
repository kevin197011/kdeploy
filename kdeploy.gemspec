# frozen_string_literal: true

require_relative 'lib/kdeploy/version'

Gem::Specification.new do |spec|
  spec.name = 'kdeploy'
  spec.version = Kdeploy::VERSION
  spec.authors = ['Kdeploy Team']
  spec.email = ['kevin197011@outlook.com']

  spec.summary = 'Lightweight agentless deployment tool with DSL, heredoc, and ERB template support'
  spec.description = <<~DESC
    Kdeploy is a lightweight, agentless deployment tool similar to Chef, Puppet, and Ansible.
    It uses Ruby DSL for defining deployment pipelines with support for inventory management,
    parallel execution, SSH-based remote operations, heredoc syntax for multi-line scripts,
    and ERB templates for dynamic configuration generation.
  DESC
  spec.homepage = 'https://github.com/kevin197011/kdeploy'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kevin197011/kdeploy'
  spec.metadata['changelog_uri'] = 'https://github.com/kevin197011/kdeploy/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[exe/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core Dependencies
  spec.add_dependency 'colorize', '~> 0.8' # 终端颜色支持
  spec.add_dependency 'concurrent-ruby', '~> 1.2' # 并发支持
  spec.add_dependency 'net-scp', '~> 4.0'         # SCP 文件传输
  spec.add_dependency 'net-ssh', '~> 7.0'         # SSH 连接
  spec.add_dependency 'thor', '~> 1.3'            # CLI 工具
  spec.add_dependency 'tty-prompt', '~> 0.23'     # 交互式提示
  spec.add_dependency 'tty-spinner', '~> 0.9'     # 进度显示
  spec.add_dependency 'tty-table', '~> 0.12'      # 表格输出
  spec.add_dependency 'yaml', '~> 0.2'            # YAML 支持

  # Extended Dependencies
  spec.add_dependency 'activesupport', '~> 7.0'   # 工具集
  spec.add_dependency 'erubi', '~> 1.12'          # ERB 模板
  spec.add_dependency 'pastel', '~> 0.8'          # 终端样式
  spec.add_dependency 'tty-logger', '~> 0.6'      # 日志管理
  spec.add_dependency 'tty-progressbar', '~> 0.18' # 进度条
  spec.add_dependency 'zeitwerk', '~> 2.6' # 自动加载

  # Development Dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'yard', '~> 0.9'
end
