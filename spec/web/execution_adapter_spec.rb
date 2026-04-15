# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'tmpdir'

ENV['JOB_CONSOLE_DB'] = 'sqlite::memory:'

require_relative '../../web-ui/lib/execution_adapter'
require_relative '../../web-ui/lib/db'

RSpec.describe Kdeploy::Web::ExecutionAdapter do
  before do
    Kdeploy::Web::DB.connect!(url: ENV.fetch('JOB_CONSOLE_DB', nil))
    migrations_dir = File.expand_path('../../web-ui/db/migrate', __dir__)
    Sequel::Migrator.run(Kdeploy::Web::DB.db, migrations_dir)
  end

  it 'injects default variables before task file evaluation' do
    Dir.mktmpdir do |dir|
      ENV['JOB_CONSOLE_TASK_BASE_DIR'] = dir
      task_file = File.join(dir, 'deploy.rb')
      File.write(task_file, <<~'RUBY')
        host 'web01', user: 'ubuntu', ip: '10.0.0.1'
        task :demo do
          run "echo #{greeting}"
        end
      RUBY

      Kdeploy::Web::Models::Job.create(
        name: 'demo',
        task_file_path: task_file,
        default_variables_json: JSON.generate(greeting: 'hello'),
        created_at: Time.now,
        updated_at: Time.now
      )

      runner = instance_double(Kdeploy::Runner, run: {})
      allow(Kdeploy::Runner).to receive(:new).and_return(runner)

      expect do
        described_class.execute(
          task_file_path: task_file,
          task_name: 'demo',
          limit: nil,
          parallel: nil,
          retries: nil,
          retry_delay: nil,
          format: 'json',
          on_step: nil
        )
      end.not_to raise_error
    end
  end
end
