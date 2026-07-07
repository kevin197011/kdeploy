# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Kdeploy::Configuration do
  after do
    described_class.reset
  end

  it 'loads task-dir config over cwd defaults' do
    Dir.mktmpdir do |cwd|
      Dir.mktmpdir do |project|
        File.write(File.join(cwd, described_class::CONFIG_FILE_NAME), "parallel: 3\n")
        File.write(File.join(project, described_class::CONFIG_FILE_NAME), "parallel: 7\n")

        described_class.load_for_execute(cwd: cwd, task_dir: project)
        expect(described_class.default_parallel).to eq(7)
      end
    end
  end

  it 'applies KDEPLOY_* environment overrides' do
    ENV['KDEPLOY_PARALLEL'] = '4'
    ENV['KDEPLOY_SSH_TIMEOUT'] = '45'

    described_class.load_for_execute
    expect(described_class.default_parallel).to eq(4)
    expect(described_class.default_ssh_timeout).to eq(45)
  ensure
    ENV.delete('KDEPLOY_PARALLEL')
    ENV.delete('KDEPLOY_SSH_TIMEOUT')
  end
end
