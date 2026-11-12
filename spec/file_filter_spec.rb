# frozen_string_literal: true

RSpec.describe Kdeploy::FileFilter do
  it 'matches *.log in any directory' do
    filter = described_class.new(ignore_patterns: ['*.log'])
    expect(filter.ignored?('a.log')).to be(true)
    expect(filter.ignored?('logs/a.log')).to be(true)
    expect(filter.ignored?('a.txt')).to be(false)
  end
end
