# frozen_string_literal: true

require 'pathname'

module Kdeploy
  # File filter for directory synchronization
  # Supports .gitignore-style patterns
  class FileFilter
    def initialize(ignore_patterns: [])
      @ignore_patterns = normalize_patterns(ignore_patterns)
    end

    # Check if a file should be ignored
    def ignored?(file_path, base_path = nil)
      relative_path = relative_path_for(file_path, base_path)
      @ignore_patterns.any? { |pattern| match_pattern?(pattern, relative_path) }
    end

    # Filter files from a directory
    def filter_files(files, base_path = nil)
      files.reject { |file| ignored?(file, base_path) }
    end

    private

    def normalize_patterns(patterns)
      patterns.map do |pattern|
        normalize_pattern(pattern)
      end
    end

    def normalize_pattern(pattern)
      # Remove leading slash if present (patterns are relative to base)
      pattern = pattern.sub(%r{\A/}, '')
      # Convert to regex
      pattern_to_regex(pattern)
    end

    def pattern_to_regex(pattern)
      # Convert .gitignore-style pattern to regex
      regex_str = pattern
                  .gsub('.', '\.') # Escape dots
                  .gsub('**', '__STAR_STAR__') # Temporarily replace **
                  .gsub('*', '[^/]*') # * matches anything except /
                  .gsub('__STAR_STAR__', '.*') # ** matches anything including /
                  .gsub('?', '[^/]')         # ? matches single char except /
                  .gsub('[!', '[^')          # [^...] negation
                  .gsub('[', '[')            # Character class

      # Anchor to start if pattern doesn't start with **
      regex_str = "^#{regex_str}" unless pattern.start_with?('**')
      # Match end of string or directory separator
      regex_str = "#{regex_str}(/|$)" unless pattern.end_with?('*') || pattern.end_with?('**')

      Regexp.new(regex_str)
    end

    def match_pattern?(pattern, file_path)
      return false if file_path.nil? || file_path.empty?

      pattern.match?(file_path)
    end

    def relative_path_for(file_path, base_path)
      return file_path.to_s unless base_path

      base = Pathname.new(base_path)
      file = Pathname.new(file_path)
      file.relative_path_from(base).to_s
    end
  end
end
