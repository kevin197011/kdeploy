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

  it 'retries transient SSHError and succeeds within retry budget' do
    executor = instance_double(Kdeploy::Executor)
    allow(Kdeploy::Executor).to receive(:new).and_return(executor)

    calls = 0
    allow(executor).to receive(:execute) do
      calls += 1
      raise(Kdeploy::SSHError, 'boom') if calls < 3

      { stdout: 'ok', stderr: '', command: "echo 'test'" }
    end

    # Avoid sleeping in tests
    allow_any_instance_of(Kdeploy::CommandExecutor).to receive(:sleep)

    runner = described_class.new(hosts, { deploy: task }, retries: 2, retry_delay: 1)
    results = runner.run(:deploy)

    expect(calls).to eq(3)
    expect(results['web01'][:status]).to eq(:success)
    expect(results['web01'][:output].first[:type]).to eq(:run)
  end

  it 'fails when transient SSHError exceeds retry budget' do
    executor = instance_double(Kdeploy::Executor)
    allow(Kdeploy::Executor).to receive(:new).and_return(executor)
    allow(executor).to receive(:execute).and_raise(Kdeploy::SSHError.new('boom'))

    allow_any_instance_of(Kdeploy::CommandExecutor).to receive(:sleep)

    runner = described_class.new(hosts, { deploy: task }, retries: 1, retry_delay: 1)
    results = runner.run(:deploy)

    expect(results['web01'][:status]).to eq(:failed)
    expect(results['web01'][:error]).to match(/task=deploy/)
    expect(results['web01'][:error]).to match(/host=web01/)
  end

  it 'retries nonzero exit when enabled' do
    executor = instance_double(Kdeploy::Executor)
    allow(Kdeploy::Executor).to receive(:new).and_return(executor)

    calls = 0
    allow(executor).to receive(:execute) do
      calls += 1
      raise Kdeploy::SSHError.new('Command exited with status 1', nil, command: 'false', exit_status: 1) if calls < 2

      { stdout: 'ok', stderr: '', command: 'echo ok', exit_status: 0 }
    end

    allow_any_instance_of(Kdeploy::CommandExecutor).to receive(:sleep)

    runner = described_class.new(hosts, { deploy: task }, retries: 1, retry_delay: 1, retry_on_nonzero: true)
    results = runner.run(:deploy)

    expect(calls).to eq(2)
    expect(results['web01'][:status]).to eq(:success)
  end

  it 'does not retry nonzero exit when disabled' do
    executor = instance_double(Kdeploy::Executor)
    allow(Kdeploy::Executor).to receive(:new).and_return(executor)

    allow(executor).to receive(:execute)
      .and_raise(Kdeploy::SSHError.new('Command exited with status 1', nil, command: 'false', exit_status: 1))

    allow_any_instance_of(Kdeploy::CommandExecutor).to receive(:sleep)

    runner = described_class.new(hosts, { deploy: task }, retries: 2, retry_delay: 1, retry_on_nonzero: false)
    results = runner.run(:deploy)

    expect(results['web01'][:status]).to eq(:failed)
    expect(results['web01'][:error]).to match(/exit_status=1/)
  end
end
