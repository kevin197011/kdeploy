# frozen_string_literal: true

module Kdeploy
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
        hosts: if on.is_a?(Array)
                 on
               else
                 (on ? [on] : nil)
               end,
        roles: if roles.is_a?(Array)
                 roles
               else
                 (roles ? [roles] : nil)
               end,
        block: lambda {
          @kdeploy_commands = []
          instance_eval(&block)
          @kdeploy_commands
        }
      }
    end

    def run(command)
      @kdeploy_commands ||= []
      @kdeploy_commands << { type: :run, command: command }
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

    def inventory(&)
      instance_eval(&) if block_given?
    end

    def get_task_hosts(task_name)
      task = kdeploy_tasks[task_name]
      return kdeploy_hosts.keys if !task || (!task[:hosts] && !task[:roles])

      hosts = Set.new

      # 添加指定的主机
      task[:hosts]&.each do |host|
        hosts.add(host) if kdeploy_hosts.key?(host)
      end

      # 添加角色中的主机
      task[:roles]&.each do |role|
        next unless (role_hosts = kdeploy_roles[role])

        role_hosts.each do |host|
          hosts.add(host) if kdeploy_hosts.key?(host)
        end
      end

      hosts.to_a
    end
  end
end
