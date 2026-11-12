# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'stringio'

RSpec.describe 'Kdeploy 1.4 features' do
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it 'writes --report JSON and filters --tags' do
    Dir.mktmpdir do |dir|
      deploy = File.join(dir, 'deploy.rb')
      File.write(deploy, <<~RUBY)
        host "web01", user: "ubuntu", ip: "10.0.0.1"
        vars app: "from-dsl"
        task :alpha, tags: [:web] do
          run "echo %{app}"
        end
        task :beta, tags: [:db] do
          run "echo beta"
        end
      RUBY
      report = File.join(dir, 'report.json')

      executor = instance_double(Kdeploy::Executor)
      allow(Kdeploy::Executor).to receive(:new).and_return(executor)
      allow(executor).to receive(:execute).and_return(
        { stdout: 'from-cli', stderr: '', command: 'echo from-cli', exit_status: 0 }
      )

      expect do
        capture_stdout do
          Kdeploy::CLI.start([
                               'execute', deploy, '--tags', 'web',
                               '--extra-vars', 'app=from-cli',
                               '--report', report, '--no-banner'
                             ])
        end
      end.not_to raise_error

      payload = JSON.parse(File.read(report))
      expect(payload['version']).to eq(Kdeploy::VERSION)
      expect(payload['generated_at']).to match(/\d{4}-\d{2}-\d{2}T/)
      expect(payload['tasks'].keys).to eq(['alpha'])
    end
  end

  it 'defaults verify_host_key to accept_new' do
    Kdeploy::Configuration.reset
    expect(Kdeploy::Configuration.default_verify_host_key).to eq(:accept_new)
  end
end
