# frozen_string_literal: true

require 'set'
require 'shellwords'

module Kdeploy
  # Helper for template resource block: captures source and variables
  class TemplateOptions
    def initialize
      @source = nil
      @variables = {}
    end

    def variables(val = nil)
      @variables = val if val
      @variables
    end

    def source(val = nil)
      @source = val if val
      @source
    end
  end

  # Per-invocation collector so parallel hosts do not race on DSL ivars.
  class TaskContext
    def initialize(dsl, commands, on_failure_commands, vars)
      @dsl = dsl
      @commands = commands
      @on_failure_commands = on_failure_commands
      @vars = vars.transform_keys(&:to_sym)
      @failure_mode = false
    end

    def on_failure(&block)
      raise ArgumentError, 'on_failure requires a block' unless block

      previous = @failure_mode
      @failure_mode = true
      instance_eval(&block)
    ensure
      @failure_mode = previous
    end

    def run(command, sudo: nil)
      buf << { type: :run, command: interpolate(command), sudo: sudo }
    end

    def upload(source, destination)
      buf << { type: :upload, source: interpolate(source), destination: interpolate(destination) }
    end

    def upload_template(source, destination, variables = {})
      buf << {
        type: :upload_template,
        source: interpolate(source),
        destination: interpolate(destination),
        variables: interpolate_hash(variables)
      }
    end

    def sync(source, destination, ignore: [], delete: false, exclude: [], fast: nil, parallel: nil)
      buf << {
        type: :sync,
        source: interpolate(source),
        destination: interpolate(destination),
        ignore: Array(ignore).map { |p| interpolate(p.to_s) },
        exclude: Array(exclude).map { |p| interpolate(p.to_s) },
        delete: delete,
        fast: fast,
        parallel: parallel
      }
    end

    def package(name, version: nil, platform: :apt)
      cmd = @dsl.build_package_command(interpolate(name.to_s), version && interpolate(version.to_s), platform)
      buf << { type: :run, command: cmd, sudo: true }
    end

    def service(name, action: :start)
      Array(action).each do |a|
        cmd = "systemctl #{a} #{Shellwords.escape(interpolate(name.to_s))}"
        buf << { type: :run, command: cmd, sudo: true }
      end
    end

    def template(destination, source: nil, variables: nil, &block)
      if block
        opts = TemplateOptions.new
        opts.instance_eval(&block)
        src = opts.source || raise(ArgumentError, 'template requires source')
        vars = opts.variables || {}
      else
        raise ArgumentError, 'template requires source' unless source

        src = source
        vars = variables || {}
      end
      upload_template(src, destination, vars)
    end

    def file(destination, source:)
      upload(source, destination)
    end

    def directory(path, mode: nil)
      cmd = "mkdir -p #{Shellwords.escape(interpolate(path.to_s))}"
      buf << { type: :run, command: cmd, sudo: true }
      return unless mode

      buf << { type: :run, command: "chmod #{mode} #{Shellwords.escape(interpolate(path.to_s))}", sudo: true }
    end

    def wait_port(port, timeout: 30, interval: 1)
      buf << {
        type: :wait_port,
        port: port.to_i,
        timeout: timeout.to_f,
        interval: interval.to_f
      }
    end

    def wait_http(url, timeout: 30, interval: 1, code: 200)
      buf << {
        type: :wait_http,
        url: interpolate(url),
        timeout: timeout.to_f,
        interval: interval.to_f,
        code: code.to_i
      }
    end

    private

    def buf
      @failure_mode ? @on_failure_commands : @commands
    end

    def interpolate(value)
      @dsl.interpolate_string(value, @vars)
    end

    def interpolate_hash(hash)
      hash.to_h.transform_values { |v| v.is_a?(String) ? interpolate(v) : v }
    end
  end

  # Domain-specific language for defining hosts, roles, and tasks
  module DSL
    def self.included(base)
      base.extend(self)
    end

    def self.extended(base)
      base.instance_variable_set(:@kdeploy_hosts, {})
      base.instance_variable_set(:@kdeploy_tasks, {})
      base.instance_variable_set(:@kdeploy_roles, {})
      base.instance_variable_set(:@kdeploy_vars, {})
    end

    def hosts
      kdeploy_hosts
    end

    def tasks
      kdeploy_tasks
    end

    def roles
      kdeploy_roles
    end

    def kdeploy_hosts
      @kdeploy_hosts ||= {}
    end

    def kdeploy_tasks
      @kdeploy_tasks ||= {}
    end

    def kdeploy_roles
      @kdeploy_roles ||= {}
    end

    def kdeploy_vars
      @kdeploy_vars ||= {}
    end

    def clear_inventory!
      kdeploy_hosts.clear
      kdeploy_roles.clear
      kdeploy_tasks.clear
      kdeploy_vars.clear
    end

    def vars(hash = nil, **kwargs)
      merged = {}
      merged.merge!(hash) if hash.is_a?(Hash)
      merged.merge!(kwargs)
      merged.each { |k, v| kdeploy_vars[k.to_sym] = v }
      kdeploy_vars
    end

    def merge_extra_vars!(extra)
      return if extra.nil? || extra.empty?

      extra.each { |k, v| kdeploy_vars[k.to_sym] = v }
    end

    def interpolate_string(value, local_vars = {})
      return value unless value.is_a?(String)
      return value unless value.include?('%{')

      binding_vars = kdeploy_vars.merge(local_vars.transform_keys(&:to_sym))
      value.gsub(/%\{(\w+)\}/) do
        key = Regexp.last_match(1).to_sym
        raise ArgumentError, "Unknown variable %{#{key}}" unless binding_vars.key?(key)

        binding_vars[key].to_s
      end
    end

    def host(name, **options)
      kdeploy_hosts[name] = options.merge(name: name)
    end

    def role(name, hosts)
      kdeploy_roles[name] = hosts
    end

    def task(name, on: nil, roles: nil, tags: nil, &block)
      kdeploy_tasks[name] = {
        hosts: normalize_hosts_option(on),
        roles: normalize_roles_option(roles),
        tags: normalize_tags_option(tags),
        block: create_task_block(block)
      }
    end

    def assign_task(task_name, on: nil, roles: nil, tags: nil)
      task = kdeploy_tasks[task_name.to_sym]
      raise ArgumentError, "Task #{task_name} not found" unless task

      task[:hosts] = normalize_hosts_option(on) if on
      task[:roles] = normalize_roles_option(roles) if roles
      task[:tags] = normalize_tags_option(tags) if tags
    end

    def include_tasks(file_path, roles: nil, on: nil)
      unless File.absolute_path?(file_path)
        caller_file = caller_locations(1, 1).first.path
        base_dir = File.dirname(File.expand_path(caller_file))
        file_path = File.expand_path(file_path, base_dir)
      end

      tasks_before = kdeploy_tasks.keys
      module_eval(File.read(file_path), file_path)
      new_tasks = kdeploy_tasks.keys - tasks_before

      new_tasks.each do |task_name|
        task = kdeploy_tasks[task_name]
        next if task[:hosts] || task[:roles]

        assign_task(task_name, roles: roles, on: on) if roles || on
      end
    end

    def normalize_hosts_option(on)
      return on if on.is_a?(Array)
      return [on] if on

      nil
    end

    def normalize_roles_option(roles)
      return roles if roles.is_a?(Array)
      return [roles] if roles

      nil
    end

    def normalize_tags_option(tags)
      return nil if tags.nil?

      Array(tags).map { |t| t.to_s.to_sym }
    end

    def create_task_block(block)
      dsl = self
      lambda {
        commands = []
        on_failure = []
        ctx = TaskContext.new(dsl, commands, on_failure, dsl.kdeploy_vars.dup)
        ctx.instance_eval(&block)
        { commands: commands, on_failure: on_failure }
      }
    end

    def self.normalize_plan(raw)
      case raw
      when Hash
        {
          commands: Array(raw[:commands] || raw['commands']),
          on_failure: Array(raw[:on_failure] || raw['on_failure'])
        }
      when Array
        { commands: raw, on_failure: [] }
      else
        { commands: Array(raw), on_failure: [] }
      end
    end

    def inventory(&block)
      instance_eval(&block) if block_given?
    end

    def get_task_hosts(task_name)
      task = kdeploy_tasks[task_name]
      return kdeploy_hosts.keys if task_empty?(task)

      hosts = Set.new
      add_explicit_hosts(task, hosts)
      add_role_hosts(task, hosts)
      hosts.to_a
    end

    def tasks_matching_tags(tag_list)
      wanted = Array(tag_list).map { |t| t.to_s.to_sym }
      return kdeploy_tasks.keys if wanted.empty?

      kdeploy_tasks.select do |_name, task|
        task[:tags]&.any? { |t| wanted.include?(t) }
      end.keys
    end

    def task_empty?(task)
      !task || (!task[:hosts] && !task[:roles])
    end

    def add_explicit_hosts(task, hosts)
      task[:hosts]&.each do |host|
        if kdeploy_hosts.key?(host)
          hosts.add(host)
        else
          warn "Warning: task host not in inventory (skipped): #{host}"
        end
      end
    end

    def add_role_hosts(task, hosts)
      task[:roles]&.each do |role|
        role_hosts = kdeploy_roles[role]
        unless role_hosts
          warn "Warning: task role not defined (skipped): #{role}"
          next
        end

        role_hosts.each do |host|
          if kdeploy_hosts.key?(host)
            hosts.add(host)
          else
            warn "Warning: role #{role} host not in inventory (skipped): #{host}"
          end
        end
      end
    end

    def build_package_command(name, version, platform)
      n = Shellwords.escape(name.to_s)
      case platform.to_sym
      when :yum, :rpm
        if version
          "yum install -y #{n}-#{Shellwords.escape(version.to_s)}"
        else
          "yum install -y #{n}"
        end
      else
        base = "apt-get update && apt-get install -y #{n}"
        version ? "#{base}=#{Shellwords.escape(version.to_s)}" : base
      end
    end
  end
end
