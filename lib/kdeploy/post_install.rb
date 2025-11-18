# frozen_string_literal: true

module Kdeploy
  # Post-installation configuration handler
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
        update_shell_config(bashrc_path, source_line, /source.*kdeploy\.bash/)
        puts "✅ Bash completion configured in #{bashrc_path}"
      rescue StandardError => e
        puts "⚠️  Failed to configure Bash completion: #{e.message}"
      end

      def setup_zsh_completion
        return unless File.exist?(zshrc_path)

        completion_path = find_completion_file('kdeploy.zsh')
        return if completion_path.nil?

        source_lines = build_zsh_source_lines(completion_path)
        update_zsh_config(zshrc_path, source_lines)
        puts "✅ Zsh completion configured in #{zshrc_path}"
      rescue StandardError => e
        puts "⚠️  Failed to configure Zsh completion: #{e.message}"
      end

      def find_completion_file(filename)
        paths = build_completion_paths(filename)

        paths.each do |path|
          found_path = search_path(path)
          return found_path if found_path
        end

        report_completion_file_not_found(filename, paths)
        nil
      end

      def bashrc_path
        File.join(Dir.home, '.bashrc')
      end

      def zshrc_path
        File.join(Dir.home, '.zshrc')
      end

      def update_shell_config(config_path, source_line, pattern)
        content = File.read(config_path)
        if content.match?(pattern)
          new_content = content.gsub(/#{pattern.source}.*$/, source_line)
          File.write(config_path, new_content)
        else
          append_shell_config(config_path, source_line)
        end
      end

      def append_shell_config(config_path, source_line)
        File.open(config_path, 'a') do |f|
          f.puts "\n# Kdeploy completion"
          f.puts source_line
        end
      end

      def build_zsh_source_lines(completion_path)
        [
          "source \"#{completion_path}\"",
          'autoload -Uz compinit && compinit'
        ]
      end

      def update_zsh_config(zshrc_path, source_lines)
        content = File.read(zshrc_path)
        if content.match?(/source.*kdeploy\.zsh/)
          new_content = content.gsub(/source.*kdeploy\.zsh.*$/, source_lines[0])
          File.write(zshrc_path, new_content)
        else
          append_zsh_config(zshrc_path, source_lines, content)
        end
      end

      def append_zsh_config(zshrc_path, source_lines, content)
        File.open(zshrc_path, 'a') do |f|
          f.puts "\n# Kdeploy completion"
          source_lines.each { |line| f.puts line unless content.include?(line) }
        end
      end

      def build_completion_paths(filename)
        [
          File.expand_path("../completions/#{filename}", __FILE__),
          *Gem.path.map { |path| File.join(path, "gems/kdeploy-*/lib/kdeploy/completions/#{filename}") },
          "/usr/local/share/kdeploy/completions/#{filename}",
          "/usr/share/kdeploy/completions/#{filename}"
        ]
      end

      def search_path(path)
        if path.include?('*')
          matches = Dir.glob(path)
          return matches.first if matches.any?
        elsif File.exist?(path)
          return path
        end
        nil
      end

      def report_completion_file_not_found(filename, paths)
        puts "⚠️  Could not find completion file: #{filename}"
        puts 'Searched paths:'
        paths.each { |path| puts "  - #{path}" }
      end
    end
  end
end
