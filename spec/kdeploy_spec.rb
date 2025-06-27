# frozen_string_literal: true

RSpec.describe Kdeploy do
  it 'has a version number' do
    expect(Kdeploy::VERSION).not_to be_nil
  end

  describe '.configure' do
    it 'yields configuration block' do
      expect { |b| Kdeploy.configure(&b) }.to yield_with_args(kind_of(Kdeploy::Configuration))
    end

    it 'sets configuration' do
      Kdeploy.configure do |config|
        config.max_concurrent_tasks = 5
      end

      expect(Kdeploy.configuration.max_concurrent_tasks).to eq(5)
    end
  end

  describe '.load_script' do
    let(:script_content) do
      <<~RUBY
        host 'test.example.com', user: 'testuser'

        task 'test_task' do
          run 'echo "Hello World"'
        end
      RUBY
    end

    let(:script_file) { 'test_script.rb' }

    before do
      File.write(script_file, script_content)
    end

    after do
      FileUtils.rm_f(script_file)
    end

    it 'loads and parses deployment script' do
      pipeline = Kdeploy.load_script(script_file)

      expect(pipeline).to be_a(Kdeploy::Pipeline)
      expect(pipeline.hosts.size).to eq(1)
      expect(pipeline.tasks.size).to eq(1)
      expect(pipeline.hosts.first.hostname).to eq('test.example.com')
      expect(pipeline.tasks.first.name).to eq('test_task')
    end

    it 'raises error for non-existent script' do
      expect { Kdeploy.load_script('nonexistent.rb') }.to raise_error(Kdeploy::ConfigurationError)
    end
  end

  describe '.execute' do
    let(:host) { create_test_host('test.example.com') }
    let(:pipeline) { create_test_pipeline }

    before do
      pipeline.add_host('test.example.com', user: 'testuser')
      task = pipeline.add_task('test_task')
      task.add_command('test_command', 'echo "Hello"')
    end

    it 'executes pipeline using runner' do
      runner = instance_double(Kdeploy::Runner)
      allow(Kdeploy::Runner).to receive(:new).with(pipeline).and_return(runner)
      allow(runner).to receive(:execute).and_return({ success: true })

      result = Kdeploy.execute(pipeline)

      expect(result[:success]).to be true
    end
  end

  describe '.run' do
    let(:script_content) do
      <<~RUBY
        host 'test.example.com', user: 'testuser'

        task 'test_task' do
          run 'echo "Hello World"'
        end
      RUBY
    end

    let(:script_file) { 'test_script.rb' }

    before do
      File.write(script_file, script_content)
    end

    after do
      FileUtils.rm_f(script_file)
    end

    it 'loads and executes script' do
      runner = instance_double(Kdeploy::Runner)
      allow(Kdeploy::Runner).to receive(:new).and_return(runner)
      allow(runner).to receive(:execute).and_return({ success: true })

      result = Kdeploy.run(script_file)

      expect(result[:success]).to be true
    end
  end
end
