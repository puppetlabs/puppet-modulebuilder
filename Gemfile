# frozen_string_literal: true

# For puppetcore, set GEM_SOURCE_PUPPETCORE = 'https://rubygems-puppetcore.puppet.com'
gemsource_default = ENV['GEM_SOURCE'] || 'https://rubygems.org'
gemsource_puppetcore = if ENV['PUPPET_FORGE_TOKEN'].to_s.empty?
                         ENV['GEM_SOURCE_PUPPETCORE'] || gemsource_default
                       else
                         'https://rubygems-puppetcore.puppet.com'
                       end
source gemsource_default

# Specify your gem's dependencies in puppet-modulebuilder.gemspec
gemspec

def location_for(place_or_version, fake_version = nil, opts = {})
  git_url_regex = /\A(?<url>(https?|git)[:@][^#]*)(#(?<branch>.*))?/
  file_url_regex = %r{\Afile://(?<path>.*)}

  if place_or_version && (git_url = place_or_version.match(git_url_regex))
    [fake_version, { git: git_url[:url], branch: git_url[:branch], require: false }].compact
  elsif place_or_version && (file_url = place_or_version.match(file_url_regex))
    ['>= 0', { path: File.expand_path(file_url[:path]), require: false }]
  else
    [place_or_version, { require: false }.merge(opts)]
  end
end

group :development do
  gem 'puppet', *location_for(ENV.fetch('PUPPET_GEM_VERSION', nil), nil, { source: gemsource_puppetcore })

  gem 'rake'
  gem 'rspec', '~> 3.1'

  gem 'simplecov'
  gem 'simplecov-console'

  # Required for testing on Windows
  gem 'ffi', platforms: [:x64_mingw]
  # puppet-modulebuilder supports minitar 0.x and 1.x
  # puppet 8.10.0 can use `tar` (the linux CLI tool) *or* minitar 0.x
  # on windows, puppet 8.10 defaults to minitar
  gem 'minitar', '~> 0.9', platforms: [:x64_mingw]
end
