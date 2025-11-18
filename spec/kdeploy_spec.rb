# frozen_string_literal: true

RSpec.describe Kdeploy do
  it 'has a version number' do
    expect(Kdeploy::VERSION).not_to be nil
  end

  describe Kdeploy::DSL do
    let(:klass) { Class.new { include Kdeploy::DSL } }

    it 'can define hosts' do
      klass.host 'web01', user: 'ubuntu', ip: '10.0.0.1'
      expect(klass.hosts['web01']).to include(
        name: 'web01',
        user: 'ubuntu',
        ip: '10.0.0.1'
      )
    end

    it 'can define tasks' do
      klass.task :deploy do
        run "echo 'hello'"
      end
      expect(klass.tasks[:deploy]).to be_a(Proc)
    end
  end

  describe Kdeploy::Executor do
    let(:host_config) do
      {
        name: 'web01',
        user: 'ubuntu',
        ip: '10.0.0.1',
        key: '~/.ssh/id_rsa'
      }
    end

    subject { described_class.new(host_config) }

    it 'initializes with host config' do
      expect(subject.instance_variable_get(:@host)).to eq('web01')
      expect(subject.instance_variable_get(:@user)).to eq('ubuntu')
      expect(subject.instance_variable_get(:@ip)).to eq('10.0.0.1')
    end
  end

  describe Kdeploy::Runner do
    let(:hosts) do
      {
        'web01' => { name: 'web01', user: 'ubuntu', ip: '10.0.0.1' }
      }
    end

    let(:tasks) do
      {
        deploy: -> { [{ type: :run, command: "echo 'test'" }] }
      }
    end

    subject { described_class.new(hosts, tasks) }

    it 'initializes with hosts and tasks' do
      expect(subject.instance_variable_get(:@hosts)).to eq(hosts)
      expect(subject.instance_variable_get(:@tasks)).to eq(tasks)
    end
  end
end
