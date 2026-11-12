# frozen_string_literal: true

require 'tempfile'

RSpec.describe Kdeploy::Template do
  it 'raises a clear error when template variables are missing' do
    content = 'hello <%= name %> <%= env %>'
    file = Tempfile.new('kdeploy_template')
    file.write(content)
    file.close

    expect do
      described_class.render(file.path, name: 'world')
    end.to raise_error(ArgumentError, /Missing template variables: env/)
  ensure
    file&.unlink
  end

  it 'detects <%= @name %> style variables' do
    content = 'hello <%= @name %>'
    file = Tempfile.new('kdeploy_template_ivar')
    file.write(content)
    file.close

    expect do
      described_class.render(file.path, {})
    end.to raise_error(ArgumentError, /Missing template variables: name/)
  ensure
    file&.unlink
  end
end

RSpec.describe Kdeploy::Executor do
  it 'does not wrap missing variables as TemplateError on upload_template' do
    executor = described_class.new(name: 'web01', user: 'u', ip: '1.2.3.4', key: 'k')
    file = Tempfile.new(['missing', '.erb'])
    file.write('Hello <%= name %>')
    file.close
    expect do
      executor.upload_template(file.path, '/tmp/x', {})
    end.to raise_error(ArgumentError, /Missing template variables/)
  ensure
    file&.unlink
  end
end
