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
        content = File.read(bashrc_path)
        if content.match?(/source.*kdeploy\.bash/)
          # 更新现有的配置
          new_content = content.gsub(/source.*kdeploy\.bash.*$/, source_line)
          File.write(bashrc_path, new_content)
        else
          # 添加新配置
          File.open(bashrc_path, 'a') do |f|
            f.puts "\n# Kdeploy completion"
            f.puts source_line
          end
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
        if content.match?(/source.*kdeploy\.zsh/)
          # 更新现有的配置
          new_content = content.gsub(/source.*kdeploy\.zsh.*$/, source_lines[0])
          File.write(zshrc_path, new_content)
        else
          # 添加新配置
          File.open(zshrc_path, 'a') do |f|
            f.puts "\n# Kdeploy completion"
            source_lines.each { |line| f.puts line unless content.include?(line) }
          end
        end
        puts "✅ Zsh completion configured in #{zshrc_path}"
      rescue StandardError => e
        puts "⚠️  Failed to configure Zsh completion: #{e.message}"
      end

      def find_completion_file(filename)
        # 尝试所有可能的路径
        paths = [
          # 开发环境路径
          File.expand_path("../completions/#{filename}", __FILE__),
          # RubyGems 安装路径
          *Gem.path.map { |path| File.join(path, "gems/kdeploy-*/lib/kdeploy/completions/#{filename}") },
          # 系统路径
          "/usr/local/share/kdeploy/completions/#{filename}",
          "/usr/share/kdeploy/completions/#{filename}"
        ]

        # 使用 Dir.glob 处理通配符路径
        paths.each do |path|
          if path.include?('*')
            matches = Dir.glob(path)
            return matches.first if matches.any?
          elsif File.exist?(path)
            return path
          end
        end

        puts "⚠️  Could not find completion file: #{filename}"
        puts 'Searched paths:'
        paths.each { |path| puts "  - #{path}" }
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
