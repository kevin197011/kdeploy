# frozen_string_literal: true

require 'set'

module Kdeploy
  # Domain-specific language for defining hosts, roles, and tasks
  module DSL
    def self.extended(base)
      base.instance_variable_set(:@kdeploy_hosts, {})
      base.instance_variable_set(:@kdeploy_tasks, {})
      base.instance_variable_set(:@kdeploy_roles, {})
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
