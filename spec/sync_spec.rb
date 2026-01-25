# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Kdeploy::Executor do
  let(:host_config) do
    {
      name: 'web01',
      user: 'ubuntu',
      ip: '10.0.0.1',
      key: '~/.ssh/id_rsa'
    }
  end

  it 'sync_directory respects ignore/exclude and can call delete mode' do
    Dir.mktmpdir do |dir|
      src = File.join(dir, 'src')
      FileUtils.mkdir_p(File.join(src, 'node_modules'))
      FileUtils.mkdir_p(File.join(src, 'logs'))
      FileUtils.mkdir_p(File.join(src, 'nested'))

      File.write(File.join(src, 'keep.txt'), '1')
      File.write(File.join(src, 'logs', 'a.log'), 'log')
      File.write(File.join(src, 'node_modules', 'x.js'), 'x')
      File.write(File.join(src, 'nested', 'keep2.txt'), '2')

      executor = described_class.new(host_config)

      uploaded = []
      allow(executor).to receive(:ensure_remote_directory)
      allow(executor).to receive(:upload) do |local, remote, **_opts|
        uploaded << [local, remote]
      end
      allow(executor).to receive(:delete_extra_files).and_return(2)

      result = executor.sync_directory(
        src,
        '/var/www/app',
        ignore: ['*.log'],
        exclude: ['node_modules'],
        delete: true,
        use_sudo: false
      )

      remote_paths = uploaded.map { |_l, r| r }
      expect(remote_paths).to include('/var/www/app/keep.txt', '/var/www/app/nested/keep2.txt')
      expect(remote_paths.any? { |p| p.include?('node_modules') }).to be(false)
      expect(remote_paths.any? { |p| p.end_with?('.log') }).to be(false)

      expect(result[:uploaded]).to eq(2)
      expect(result[:deleted]).to eq(2)
      expect(result[:total]).to eq(2)
    end
  end
end
