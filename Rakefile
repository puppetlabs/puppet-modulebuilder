# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
begin
  # make rubocop optional to deal with ruby 2.1
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new(:rubocop) do |task|
    task.options = %w[-D -S -E]
  end

  task default: [:rubocop]
rescue LoadError => e
  puts "Can't load 'rubocop/rake_task': #{e.inspect}"
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:acceptance) do |t|
  t.pattern = 'spec/acceptance/**/*_spec.rb'
end

task default: [:spec, :acceptance]

if Bundler.rubygems.find_name('github_changelog_generator').any?
  require 'github_changelog_generator/task'
  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.user = 'puppetlabs'
    config.project = 'puppet-modulebuilder'
    require 'puppet/modulebuilder/version'
    config.future_release = "v#{Puppet::Modulebuilder::VERSION}"
    config.exclude_labels = ['maintenance']
    config.header = <<-HEADER
                      # Change log

                      All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).
    HEADER
                    .gsub(%r{^ *}, '')

    config.add_pr_wo_labels = true
    config.issues = false
    config.merge_prefix = '### UNCATEGORIZED PRS; GO LABEL THEM'
  end
end
