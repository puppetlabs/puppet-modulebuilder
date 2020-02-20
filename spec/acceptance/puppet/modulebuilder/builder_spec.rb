# frozen_string_literal: true

require 'spec_helper'
require 'puppet/modulebuilder/builder'

RSpec.describe Puppet::Modulebuilder::Builder do
  pending('Requires some acceptance tests to actually build a module and check the output')

  # spec_helper_acceptance
  #  - downloads an example module from git (maybe puppetlabs-stdlib?)
  #  - places it in fixtures directory
  #
  # context 'for a real module' do
  #   it 'creates the tarball'; end
  #   it 'has the same content as the source'; end
  # end
end
