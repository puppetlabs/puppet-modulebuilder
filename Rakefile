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
