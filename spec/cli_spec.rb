# frozen_string_literal: true

require 'json'
require 'stringio'
require 'tmpdir'

RSpec.describe Kdeploy::CLI do
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def write_deploy_file(dir)
    path = File.join(dir, 'deploy.rb')
    File.write(path, <<~RUBY)
      host "web01", user: "ubuntu", ip: "10.0.0.1"
      host "web02", user: "ubuntu", ip: "10.0.0.2"
      role :web, %w[web01 web02]

      task :deploy_web, roles: :web do
        run "echo hello"
      end
    RUBY
    path
  end

  it 'does not execute Runner in dry-run mode' do
    Dir.mktmpdir do |dir|
      deploy = write_deploy_file(dir)

      allow(Kdeploy::Runner).to receive(:new).and_raise('Runner should not be created in dry-run')

      expect do
        described_class.start(['execute', deploy, 'deploy_web', '--dry-run'])
      end.to output(/Dry Run Mode/).to_stdout
    end
  end

  it 'supports JSON output format for dry-run' do
    Dir.mktmpdir do |dir|
      deploy = write_deploy_file(dir)

      allow(Kdeploy::Runner).to receive(:new).and_raise('Runner should not be created in dry-run')

      json_output = capture_stdout do
        described_class.start(['execute', deploy, 'deploy_web', '--dry-run', '--format', 'json', '--no-banner'])
      end

      parsed = JSON.parse(json_output)
      expect(parsed['dry_run']).to be(true)
      expect(parsed['task']).to eq('deploy_web')
      expect(parsed['planned'].keys).to match_array(%w[web01 web02])
      expect(json_output).not_to include('Lightweight Agentless Deployment Tool')
    end
  end

  it 'exits non-zero when any host fails' do
    Dir.mktmpdir do |dir|
      deploy = write_deploy_file(dir)

      runner = instance_double(Kdeploy::Runner)
      allow(runner).to receive(:run).and_return(
        'web01' => { status: :failed, error: 'boom', output: [] },
        'web02' => { status: :success, output: [{ type: :run, command: 'echo hello', duration: 0.01, output: {} }] }
      )
      allow(Kdeploy::Runner).to receive(:new).and_return(runner)

      expect do
        described_class.start(['execute', deploy, 'deploy_web'])
      end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end

  it 'stops executing remaining tasks after a failure' do
    Dir.mktmpdir do |dir|
      deploy = File.join(dir, 'deploy.rb')
      File.write(deploy, <<~RUBY)
        host "web01", user: "ubuntu", ip: "10.0.0.1"

        task :t1 do
          run "echo t1"
        end

        task :t2 do
          run "echo t2"
        end
      RUBY

      runner = instance_double(Kdeploy::Runner)
      allow(runner).to receive(:run).and_return(
        'web01' => { status: :failed, error: 'boom', output: [] }
      )

      # If the CLI tries to execute the second task, it will create a second Runner.
      expect(Kdeploy::Runner).to receive(:new).once.and_return(runner)

      expect do
        described_class.start(['execute', deploy])
      end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end

  it 'supports JSON output format for execute results' do
    Dir.mktmpdir do |dir|
      deploy = write_deploy_file(dir)

      runner = instance_double(Kdeploy::Runner)
      allow(runner).to receive(:run).and_return(
        'web01' => {
          status: :success,
          output: [
            { type: :run, command: 'echo hello', duration: 0.01, output: { stdout: 'x', stderr: '' } }
          ]
        }
      )
      allow(Kdeploy::Runner).to receive(:new).and_return(runner)

      json_output = capture_stdout do
        described_class.start(['execute', deploy, 'deploy_web', '--format', 'json', '--no-banner'])
      end

      parsed = JSON.parse(json_output)
      expect(parsed['task']).to eq('deploy_web')
      expect(parsed['results']['web01']['status']).to eq('success')
      expect(parsed['results']['web01']['steps'].first['type']).to eq('run')
    end
  end
end
