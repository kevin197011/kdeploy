#!/usr/bin/env ruby
# frozen_string_literal: true

ENV['PORT'] ||= '4567'
ENV['JOB_CONSOLE_DB'] ||= 'sqlite:////data/job_console.sqlite3'

require_relative '../lib/db'

# Connect + auto-migrate (see DB.connect!)
Kdeploy::Web::DB.connect!

port = ENV.fetch('PORT', '4567')
puts "[kdeploy-web] DB=#{ENV.fetch('JOB_CONSOLE_DB', nil)}"
puts "[kdeploy-web] Starting on 0.0.0.0:#{port}"

exec('rackup', '-s', 'webrick', '-o', '0.0.0.0', '-p', port, 'web/config.ru')
