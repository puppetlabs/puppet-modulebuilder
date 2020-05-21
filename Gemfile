# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in puppet-modulebuilder.gemspec
gemspec

group :development do
  gem 'rake', '~> 12.0'
  gem 'rspec', '~> 3.0'
  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.3.0')
    gem 'rubocop', '~> 0.84'
    gem 'rubocop-rspec', '~> 1.38'

    gem 'codecov', '~> 0.1'
    gem 'github_changelog_generator', '~> 1.15', require: false
    gem 'simplecov', '~> 0.18'
    gem 'simplecov-console', '~> 0.6'
  end

  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.5.0')
    gem 'puppet', '~> 6.0'
  elsif Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.0')
    gem 'puppet', '~> 5.0' # rubocop:disable Bundler/DuplicatedGem Nope, not a duplicate!
  else
    gem 'puppet', '~> 4.0' # rubocop:disable Bundler/DuplicatedGem Nope, not a duplicate!
  end
end

# Evaluate Gemfile.local and ~/.gemfile if they exist
extra_gemfiles = [
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]

extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding) # rubocop:disable Security/Eval
  end
end
