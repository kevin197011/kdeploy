# frozen_string_literal: true

require 'sequel'
require 'fileutils'

module Kdeploy
  module Web
    module DB
      class << self
        def connect!(url: nil)
          Sequel.extension :migration
          @db = Sequel.connect(url || default_url)
          # Ensure Sequel::Model uses the current connection (important for tests).
          Sequel::Model.db = @db
          migrate!
          @db
        end

        def db
          @db ||= connect!
        end

        def default_url
          return ENV.fetch('JOB_CONSOLE_DB', nil) if ENV.key?('JOB_CONSOLE_DB')

          path = File.expand_path('../../db/job_console.sqlite3', __dir__)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir)
          # Sequel expects sqlite URI as sqlite:///absolute/path
          "sqlite:///#{path}"
        end

        def migrate!
          migrations_dir = File.expand_path('../db/migrate', __dir__)
          Sequel::Migrator.run(@db, migrations_dir)
        end
      end
    end
  end
end
