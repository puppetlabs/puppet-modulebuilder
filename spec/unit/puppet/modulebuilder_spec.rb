# frozen_string_literal: true

RSpec.describe Puppet::Modulebuilder do
  it 'has a version number' do
    expect(Puppet::Modulebuilder::VERSION).not_to be_nil
  end
end
