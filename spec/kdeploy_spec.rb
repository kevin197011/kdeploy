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

    it 'compiles package resource to run step' do
      klass.task :install do
        package 'nginx'
      end
      cmds = klass.tasks[:install][:block].call
      expect(cmds.size).to eq(1)
      expect(cmds[0][:type]).to eq(:run)
      expect(cmds[0][:command]).to include('apt-get')
      expect(cmds[0][:command]).to include('nginx')
      expect(cmds[0][:sudo]).to eq(true)
    end

    it 'compiles package resource with version and platform' do
      klass.task :install do
        package 'nginx', version: '1.18', platform: :apt
      end
      cmds = klass.tasks[:install][:block].call
      expect(cmds[0][:command]).to include('nginx=1.18')
      klass.task :install_yum do
        package 'nginx', platform: :yum
      end
      cmds_yum = klass.tasks[:install_yum][:block].call
      expect(cmds_yum[0][:command]).to include('yum')
    end

    it 'compiles service resource to systemctl run steps' do
      klass.task :svc do
        service 'nginx', action: %i[enable start]
      end
      cmds = klass.tasks[:svc][:block].call
      expect(cmds.size).to eq(2)
      expect(cmds[0][:command]).to include('systemctl enable nginx')
      expect(cmds[1][:command]).to include('systemctl start nginx')
    end

    it 'compiles template resource to upload_template step' do
      klass.task :tmpl do
        template '/etc/nginx/nginx.conf', source: './config/nginx.conf.erb', variables: { port: 3000 }
      end
      cmds = klass.tasks[:tmpl][:block].call
      expect(cmds.size).to eq(1)
      expect(cmds[0][:type]).to eq(:upload_template)
      expect(cmds[0][:source]).to eq('./config/nginx.conf.erb')
      expect(cmds[0][:destination]).to eq('/etc/nginx/nginx.conf')
      expect(cmds[0][:variables]).to eq(port: 3000)
    end

    it 'compiles template resource with block syntax' do
      klass.task :tmpl_block do
        template '/etc/app.conf' do
          source './config/app.erb'
          variables(domain: 'example.com')
        end
      end
      cmds = klass.tasks[:tmpl_block][:block].call
      expect(cmds.size).to eq(1)
      expect(cmds[0][:type]).to eq(:upload_template)
      expect(cmds[0][:source]).to eq('./config/app.erb')
      expect(cmds[0][:variables]).to eq(domain: 'example.com')
    end

    it 'compiles file resource to upload step' do
      klass.task :f do
        file '/etc/nginx/app.conf', source: './config/app.conf'
      end
      cmds = klass.tasks[:f][:block].call
      expect(cmds.size).to eq(1)
      expect(cmds[0][:type]).to eq(:upload)
      expect(cmds[0][:source]).to eq('./config/app.conf')
      expect(cmds[0][:destination]).to eq('/etc/nginx/app.conf')
    end

    it 'compiles directory resource to mkdir run step' do
      klass.task :dir do
        directory '/etc/nginx/conf.d'
      end
      cmds = klass.tasks[:dir][:block].call
      expect(cmds.size).to eq(1)
      expect(cmds[0][:type]).to eq(:run)
      expect(cmds[0][:command]).to include('mkdir -p')
    end

    it 'compiles directory resource with mode to mkdir and chmod' do
      klass.task :dir_mode do
        directory '/var/log/app', mode: '0755'
      end
      cmds = klass.tasks[:dir_mode][:block].call
      expect(cmds.size).to eq(2)
      expect(cmds[0][:command]).to include('mkdir -p')
      expect(cmds[1][:command]).to include('chmod 0755')
    end

    it 'mixes resource and primitive in order' do
      klass.task :mixed do
        package 'nginx'
        run 'nginx -t'
        service 'nginx', action: :restart
      end
      cmds = klass.tasks[:mixed][:block].call
      expect(cmds.size).to eq(3)
      expect(cmds[0][:type]).to eq(:run)
      expect(cmds[0][:command]).to include('apt-get')
      expect(cmds[1][:type]).to eq(:run)
      expect(cmds[1][:command]).to eq('nginx -t')
      expect(cmds[2][:type]).to eq(:run)
      expect(cmds[2][:command]).to include('systemctl restart nginx')
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
