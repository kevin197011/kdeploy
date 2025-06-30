# frozen_string_literal: true

module Kdeploy
  class PostInstall
    class << self
      def run
        setup_shell_completion
      end

      private

      def setup_shell_completion
        setup_bash_completion
        setup_zsh_completion
      end

      def setup_bash_completion
        return unless File.exist?(bashrc_path)

        completion_path = find_completion_file('kdeploy.bash')
        return if completion_path.nil?

        source_line = "source \"#{completion_path}\""

        # 检查是否已经配置
        return if File.read(bashrc_path).include?(source_line)

        # 添加配置
        File.open(bashrc_path, 'a') do |f|
          f.puts "\n# Kdeploy completion"
          f.puts source_line
        end
        puts "✅ Bash completion configured in #{bashrc_path}"
      rescue StandardError => e
        puts "⚠️  Failed to configure Bash completion: #{e.message}"
      end

      def setup_zsh_completion
        return unless File.exist?(zshrc_path)

        completion_path = find_completion_file('kdeploy.zsh')
        return if completion_path.nil?

        source_lines = [
          "source \"#{completion_path}\"",
          'autoload -Uz compinit && compinit'
        ]

        content = File.read(zshrc_path)

        # 检查是否已经配置
        return if source_lines.all? { |line| content.include?(line) }

        # 添加配置
        File.open(zshrc_path, 'a') do |f|
          f.puts "\n# Kdeploy completion"
          source_lines.each { |line| f.puts line unless content.include?(line) }
        end
        puts "✅ Zsh completion configured in #{zshrc_path}"
      rescue StandardError => e
        puts "⚠️  Failed to configure Zsh completion: #{e.message}"
      end

      def find_completion_file(filename)
        # 在开发环境中使用相对路径
        dev_path = File.expand_path("../completions/#{filename}", __FILE__)
        return dev_path if File.exist?(dev_path)

        # 在安装环境中使用 GEM_HOME
        if ENV['GEM_HOME']
          installed_path = File.join(ENV['GEM_HOME'], 'gems/kdeploy-*/lib/kdeploy/completions', filename)
          completion_files = Dir.glob(installed_path)
          return completion_files.first if completion_files.any?
        end

        nil
      end

      def bashrc_path
        File.join(Dir.home, '.bashrc')
      end

      def zshrc_path
        File.join(Dir.home, '.zshrc')
      end
    end
  end
end
