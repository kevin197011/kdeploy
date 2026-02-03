# frozen_string_literal: true

RSpec.describe Kdeploy::Runner do
  let(:hosts) do
    {
      'web01' => { name: 'web01', user: 'ubuntu', ip: '10.0.0.1' }
    }
  end

  let(:task) do
    {
      block: -> { [{ type: :run, command: "echo 'test'" }] }
    }
  end

  it 'marks host failed when execution exceeds timeout' do
    executor = instance_double(Kdeploy::Executor)
    allow(Kdeploy::Executor).to receive(:new).and_return(executor)

    allow(executor).to receive(:execute) do
      sleep(0.2)
      { stdout: 'ok', stderr: '', command: "echo 'test'", exit_status: 0 }
    end

    runner = described_class.new(hosts, { deploy: task }, host_timeout: 0.05)
    results = runner.run(:deploy)

    expect(results['web01'][:status]).to eq(:failed)
    expect(results['web01'][:error]).to match(/timeout/)
  end
end
