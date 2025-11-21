# frozen_string_literal: true

module Kdeploy
  # Groups commands by type and generates task descriptions
  class CommandGrouper
    def self.group(commands)
      commands.group_by do |cmd|
        group_key_for(cmd)
      end
    end

    def self.group_key_for(cmd)
      case cmd[:type]
      when :upload, :upload_template, :sync
        "#{cmd[:type]}_#{cmd[:source]}"
      when :run
        "#{cmd[:type]}_#{cmd[:command].to_s.lines.first.strip}"
      else
        cmd[:type].to_s
      end
    end

    def self.task_description(command)
      case command[:type]
      when :upload
        "upload #{command[:source]}"
      when :upload_template
        "template #{command[:source]}"
      when :sync
        "sync #{command[:source]}"
      when :run
        command[:command].to_s.lines.first.strip
      else
        command[:type].to_s
      end
    end
  end
end
