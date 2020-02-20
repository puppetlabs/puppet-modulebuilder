# frozen_string_literal: true

if ENV['SIMPLECOV'] == 'yes'
  begin
    require 'simplecov'
    require 'simplecov-console'
    require 'codecov'

    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
      SimpleCov::Formatter::Codecov,
    ]
    SimpleCov.start do
      track_files 'lib/**/*.rb'
      add_filter '/spec'

      # do not track vendored files
      add_filter '/vendor'
      add_filter '/.vendor'

      # do not track version file, as it is loaded before simplecov initialises and therefore is never gonna be tracked correctly
      add_filter 'lib/puppet/modulebuilder/version.rb'

      # do not track gitignored files
      # this adds about 4 seconds to the coverage check
      # this could definitely be optimized
      add_filter do |f|
        # system returns true if exit status is 0, which with git-check-ignore means file is ignored
        system("git check-ignore --quiet #{f.filename}")
      end
    end
  rescue LoadError
    raise 'Add the simplecov, simplecov-console, codecov gems to Gemfile to enable this task'
  end
end

require 'puppet/modulebuilder'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
