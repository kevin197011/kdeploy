# frozen_string_literal: true

RSpec.describe Kdeploy::Executor do
  def build(sudo_password:)
    described_class.new(
      name: 'web01', user: 'u', ip: '1.2.3.4', key: 'k',
      use_sudo: true, sudo_password: sudo_password
    )
  end

  it 'rejects sudo_password with newlines' do
    executor = build(sudo_password: "pw\nrm -rf /")
    expect { executor.send(:wrap_with_sudo, 'true') }
      .to raise_error(ArgumentError, /sudo_password/)
  end

  it 'pipes sudo password via printf rather than echo' do
    executor = build(sudo_password: 's3cret')
    wrapped = executor.send(:wrap_with_sudo, 'true')
    expect(wrapped).to include("printf '%s\\n'")
    expect(wrapped).to include('sudo -S')
    expect(wrapped).not_to include("echo '")
  end

  it 'base64-wraps compound commands for safe sudo quoting' do
    executor = build(sudo_password: 's3cret')
    wrapped = executor.send(:wrap_with_sudo, 'echo a && echo b')
    expect(wrapped).to match(/base64/)
    expect(wrapped).to include('sudo -S')
  end

  it 'closes active ssh on abort!' do
    executor = build(sudo_password: nil)
    ssh = instance_double(Net::SSH::Connection::Session, close: true)
    executor.instance_variable_set(:@active_ssh, ssh)
    executor.abort!
    expect(ssh).to have_received(:close)
    expect(executor.instance_variable_get(:@active_ssh)).to be_nil
  end
end
