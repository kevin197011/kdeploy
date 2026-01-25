# frozen_string_literal: true

require 'set'

module Kdeploy
  # Domain-specific language for defining hosts, roles, and tasks
  module DSL
    def self.included(base)
      # Support `include Kdeploy::DSL` by promoting the DSL methods to class methods.
      # This keeps tests and external integrations simpler while preserving the
      # primary usage pattern (CLI uses `extend DSL`).
      base.extend(self)
    end

    def self.extended(base)
      base.instance_variable_set(:@kdeploy_hosts, {})
      base.instance_variable_set(:@kdeploy_tasks, {})
      base.instance_variable_set(:@kdeploy_roles, {})
    end

    # Stable read accessors for tests/integrations.
    # Keep these as aliases so internal storage can evolve without breaking callers.
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

    def host(name, **options)
      kdeploy_hosts[name] = options.merge(name: name)
    end

    def role(name, hosts)
      kdeploy_roles[name] = hosts
    end

    def task(name, on: nil, roles: nil, &block)
      kdeploy_tasks[name] = {
        hosts: normalize_hosts_option(on),
        roles: normalize_roles_option(roles),
        block: create_task_block(block)
      }
    end

    # Assign task to roles or hosts after task definition
    def assign_task(task_name, on: nil, roles: nil)
      task = kdeploy_tasks[task_name.to_sym]
      raise ArgumentError, "Task #{task_name} not found" unless task

      task[:hosts] = normalize_hosts_option(on) if on
      task[:roles] = normalize_roles_option(roles) if roles
    end

    # Include task file and automatically assign all tasks to specified roles or hosts
    def include_tasks(file_path, roles: nil, on: nil)
      # Resolve relative paths based on the caller's file location
      unless File.absolute_path?(file_path)
        caller_file = caller_locations(1, 1).first.path
        base_dir = File.dirname(File.expand_path(caller_file))
        file_path = File.expand_path(file_path, base_dir)
      end

      # Store tasks before loading
      tasks_before = kdeploy_tasks.keys

      # Load the task file
      module_eval(File.read(file_path), file_path)

      # Get newly added tasks
      tasks_after = kdeploy_tasks.keys
      new_tasks = tasks_after - tasks_before

      # Assign roles/hosts to all new tasks (only if task doesn't already have hosts/roles)
      new_tasks.each do |task_name|
        task = kdeploy_tasks[task_name]
        # Only assign if task doesn't already have hosts or roles defined
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

    def create_task_block(block)
      lambda {
        @kdeploy_commands = []
        instance_eval(&block)
        @kdeploy_commands
      }
    end

    def run(command, sudo: nil)
      @kdeploy_commands ||= []
      @kdeploy_commands << { type: :run, command: command, sudo: sudo }
    end

    def upload(source, destination)
      @kdeploy_commands ||= []
      @kdeploy_commands << { type: :upload, source: source, destination: destination }
    end

    def upload_template(source, destination, variables = {})
      @kdeploy_commands ||= []
      @kdeploy_commands << {
        type: :upload_template,
        source: source,
        destination: destination,
        variables: variables
      }
    end

    def sync(source, destination, ignore: [], delete: false, exclude: [])
      @kdeploy_commands ||= []
      @kdeploy_commands << {
        type: :sync,
        source: source,
        destination: destination,
        ignore: Array(ignore),
        exclude: Array(exclude),
        delete: delete
      }
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

    def task_empty?(task)
      !task || (!task[:hosts] && !task[:roles])
    end

    def add_explicit_hosts(task, hosts)
      task[:hosts]&.each do |host|
        hosts.add(host) if kdeploy_hosts.key?(host)
      end
    end

    def add_role_hosts(task, hosts)
      task[:roles]&.each do |role|
        role_hosts = kdeploy_roles[role]
        next unless role_hosts

        role_hosts.each do |host|
          hosts.add(host) if kdeploy_hosts.key?(host)
        end
      end
    end
  end
end
