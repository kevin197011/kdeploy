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
end
