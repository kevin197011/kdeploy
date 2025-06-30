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
    end

    def execute(command)
      Net::SSH.start(@ip, @user, ssh_options) do |ssh|
        stdout = String.new
        stderr = String.new

        ssh.exec!(command) do |_channel, stream, data|
          case stream
          when :stdout
            stdout << data
          when :stderr
            stderr << data
          end
        end

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

      options
    end
  end
end
