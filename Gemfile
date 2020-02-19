# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in puppet-modulebuilder.gemspec
gemspec

gem 'rake', '~> 12.0'
gem 'rspec', '~> 3.0'
gem 'rubocop'
gem 'rubocop-rspec'

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
