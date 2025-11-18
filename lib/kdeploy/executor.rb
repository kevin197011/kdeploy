# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'

module Kdeploy
  # SSH/SCP executor for remote command execution and file operations
  class Executor
    def initialize(host_config)
      @host = host_config[:name]
      @user = host_config[:user]
      @ip = host_config[:ip]
      @password = host_config[:password]
      @key = host_config[:key]
      @port = host_config[:port] # 新增端口支持
    end

    def execute(command)
      Net::SSH.start(@ip, @user, ssh_options) do |ssh|
        execute_command_on_ssh(ssh, command)
      end
    rescue Net::SSH::AuthenticationFailed => e
      raise SSHError.new("SSH authentication failed: #{e.message}", e)
    rescue StandardError => e
      raise SSHError.new("SSH execution failed: #{e.message}", e)
    end

    def execute_command_on_ssh(ssh, command)
      stdout = String.new
      stderr = String.new

      ssh.open_channel do |channel|
        channel.exec(command) do |_ch, success|
          raise SSHError, "Could not execute command: #{command}" unless success

          setup_channel_handlers(channel, stdout, stderr)
        end
      end
      ssh.loop
      build_command_result(stdout, stderr, command)
    end

    def setup_channel_handlers(channel, stdout, stderr)
      channel.on_data do |_ch, data|
        stdout << data
      end

      channel.on_extended_data do |_ch, _type, data|
        stderr << data
      end
    end

    def build_command_result(stdout, stderr, command)
      {
        stdout: stdout.strip,
        stderr: stderr.strip,
        command: command
      }
    end

    def upload(source, destination)
      Net::SCP.start(@ip, @user, ssh_options) do |scp|
        scp.upload!(source, destination)
      end
    rescue StandardError => e
      raise SCPError.new("SCP upload failed: #{e.message}", e)
    end

    def upload_template(source, destination, variables = {})
      Template.render_and_upload(self, source, destination, variables)
    rescue StandardError => e
      raise TemplateError.new("Template upload failed: #{e.message}", e)
    end

    private

    def ssh_options
      options = base_ssh_options
      add_authentication(options)
      add_port_option(options)
      options
    end

    def base_ssh_options
      {
        verify_host_key: Configuration.default_verify_host_key,
        timeout: Configuration.default_ssh_timeout
      }
    end

    def add_authentication(options)
      if @password
        options[:password] = @password
      elsif @key
        options[:keys] = [@key]
      end
    end

    def add_port_option(options)
      options[:port] = @port if @port
    end
  end
end
