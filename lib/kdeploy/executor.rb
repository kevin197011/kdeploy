# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'

module Kdeploy
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
        stdout = String.new
        stderr = String.new

        ssh.open_channel do |channel|
          channel.exec(command) do |_ch, success|
            raise "Could not execute command: #{command}" unless success

            channel.on_data do |_ch, data|
              stdout << data
            end

            channel.on_extended_data do |_ch, _type, data|
              stderr << data
            end
          end
        end
        ssh.loop
        {
          stdout: stdout.strip,
          stderr: stderr.strip,
          command: command
        }
      end
    rescue Net::SSH::AuthenticationFailed => e
      raise "SSH authentication failed: #{e.message}"
    rescue StandardError => e
      raise "SSH execution failed: #{e.message}"
    end

    def upload(source, destination)
      Net::SCP.start(@ip, @user, ssh_options) do |scp|
        scp.upload!(source, destination)
      end
    rescue StandardError => e
      raise "SCP upload failed: #{e.message}"
    end

    def upload_template(source, destination, variables = {})
      Template.render_and_upload(self, source, destination, variables)
    rescue StandardError => e
      raise "Template upload failed: #{e.message}"
    end

    private

    def ssh_options
      options = {
        verify_host_key: :never,
        timeout: 30
      }

      if @password
        options[:password] = @password
      elsif @key
        options[:keys] = [@key]
      end
      options[:port] = @port if @port # 新增端口传递
      options
    end
  end
end
