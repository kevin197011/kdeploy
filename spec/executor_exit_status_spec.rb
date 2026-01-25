# frozen_string_literal: true

FakeBuffer = Struct.new(:long) do
  def read_long
    long
  end
end

class FakeChannel
  attr_reader :command

  def initialize(exit_status:, stdout:, stderr:)
    @exit_status = exit_status
    @stdout = stdout
    @stderr = stderr
    @on_data = nil
    @on_ext = nil
    @on_exit = nil
  end

  def exec(cmd)
    @command = cmd
    yield(self, true)
  end

  def on_data(&blk)
    @on_data = blk
  end

  def on_extended_data(&blk)
    @on_ext = blk
  end

  def on_request(name, &blk)
    @on_exit = blk if name == 'exit-status'
  end

  def trigger!
    @on_data&.call(self, @stdout) if @stdout
    @on_ext&.call(self, 1, @stderr) if @stderr
    @on_exit&.call(self, FakeBuffer.new(@exit_status)) unless @exit_status.nil?
  end
end

class FakeSSH
  def initialize(channel)
    @channel = channel
  end

  def open_channel
    yield(@channel)
  end

  def loop
    @channel.trigger!
  end
end

RSpec.describe Kdeploy::Executor do
  let(:executor) do
    described_class.new(name: 'web01', user: 'u', ip: '1.2.3.4', key: 'k')
  end

  it 'returns output when exit status is 0' do
    ssh = FakeSSH.new(FakeChannel.new(exit_status: 0, stdout: "ok\n", stderr: ''))
    result = executor.execute_command_on_ssh(ssh, 'echo ok')
    expect(result[:stdout]).to eq('ok')
    expect(result[:exit_status]).to eq(0)
  end

  it 'raises SSHError when exit status is non-zero and includes stdout/stderr' do
    ssh = FakeSSH.new(FakeChannel.new(exit_status: 2, stdout: "out\n", stderr: "bad\n"))
    expect do
      executor.execute_command_on_ssh(ssh, 'false')
    end.to raise_error(Kdeploy::SSHError) { |e|
      expect(e.exit_status).to eq(2)
      expect(e.stdout).to eq('out')
      expect(e.stderr).to eq('bad')
      expect(e.command).to eq('false')
    }
  end
end
