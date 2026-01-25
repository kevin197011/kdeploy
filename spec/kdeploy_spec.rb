# frozen_string_literal: true

require 'fileutils'

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
      expect(klass.tasks[:deploy]).to include(
        hosts: nil,
        roles: nil
      )
      expect(klass.tasks[:deploy][:block]).to respond_to(:call)
    end

    it 'resolves task hosts via roles and explicit hosts' do
      klass.host 'web01', user: 'ubuntu', ip: '10.0.0.1'
      klass.host 'web02', user: 'ubuntu', ip: '10.0.0.2'
      klass.role :web, %w[web01 web02]

      klass.task :deploy_web, roles: :web do
        run "echo 'ok'"
      end
      klass.task :maintenance, on: %w[web01] do
        run "echo 'ok'"
      end

      expect(klass.get_task_hosts(:deploy_web)).to match_array(%w[web01 web02])
      expect(klass.get_task_hosts(:maintenance)).to match_array(%w[web01])
    end

    it 'includes tasks from other files and assigns roles by default' do
      require 'tmpdir'
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'tasks'))

        tasks_file = File.join(dir, 'tasks', 't.rb')
        File.write(tasks_file, <<~RUBY)
          task :t1 do
            run "echo 1"
          end

          task :t2, roles: :db do
            run "echo 2"
          end
        RUBY

        main_file = File.join(dir, 'deploy.rb')
        File.write(main_file, <<~RUBY)
          include_tasks "tasks/t.rb", roles: :web
        RUBY

        klass.module_eval(File.read(main_file), main_file)

        expect(klass.tasks[:t1][:roles]).to eq([:web])
        # Should not override roles/on if already defined in the included file
        expect(klass.tasks[:t2][:roles]).to eq([:db])
      end
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

    it 'resolves relative upload source paths using base_dir' do
      require 'tmpdir'
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'rel.txt'), 'hi')
        executor = described_class.new(host_config.merge(base_dir: dir))

        fake_scp = instance_double(Net::SCP)
        allow(fake_scp).to receive(:upload!)

        allow(Net::SCP).to receive(:start).and_yield(fake_scp)

        executor.upload('rel.txt', '/tmp/rel.txt', use_sudo: false)

        expect(fake_scp).to have_received(:upload!).with(File.join(dir, 'rel.txt'), '/tmp/rel.txt')
      end
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
        deploy: { block: -> { [{ type: :run, command: "echo 'test'" }] } }
      }
    end

    subject { described_class.new(hosts, tasks) }

    it 'initializes with hosts and tasks' do
      expect(subject.instance_variable_get(:@hosts)).to eq(hosts)
      expect(subject.instance_variable_get(:@tasks)).to eq(tasks)
    end
  end
end
