# frozen_string_literal: true

require_relative 'lib/puppet/modulebuilder/version'

Gem::Specification.new do |spec|
  spec.name                  = 'puppet-modulebuilder'
  spec.version               = Puppet::Modulebuilder::VERSION
  spec.authors               = ['Sheena', 'Team IAC']
  spec.email                 = ['sheena@puppet.com', 'https://puppetlabs.github.io/iac/']
  spec.summary               = 'A gem to set up puppet-modulebuilder'
  spec.homepage              = 'https://github.com/puppetlabs/puppet-modulebuilder'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.1.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/puppetlabs/puppet-modulebuilder'
  spec.metadata['changelog_uri'] = 'https://github.com/puppetlabs/puppet-modulebuilder/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  # minitar and pathspec is required for building Puppet modules
  spec.add_runtime_dependency 'minitar', '~> 0.6'
  spec.add_runtime_dependency 'pathspec', '>= 0.2.1', '< 2.0.0'
end
