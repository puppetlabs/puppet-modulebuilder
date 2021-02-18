# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'puppet/modulebuilder/builder'
require 'tmpdir'

RSpec.describe Puppet::Modulebuilder::Builder do
  RSpec.shared_context 'with module source' do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:module_source) { File.join(tmp_dir, 'linked') }
    let(:module_source_actual) { File.join(tmp_dir, 'module') }
    let(:output_dir) { File.join(tmp_dir, 'pkg') }

    before(:each) do
      # Copy the module to the temporary directory
      FileUtils.cp_r(File.join(FIXTURES_DIR, 'module'), tmp_dir)

      # prepare a symlink pointing to the module. All module builder functions should work on symlinks.
      # See https://github.com/puppetlabs/puppet_litmus/pull/301 for background
      FileUtils.ln_s(module_source_actual, module_source)

      long_path = File.join(module_source_actual, 'manifests', '1234567890')
      long_path = File.join(long_path, '1234567890') while long_path.length < 1000
      FileUtils.mkdir_p(long_path)
      FileUtils.touch(File.join(long_path, 'short.pp'))
      FileUtils.touch(File.join(long_path, ('l' * 252) + '.pp'))
    end

    after(:each) do
      puts "tmp_dir: #{tmp_dir}"
      # FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir)
    end
  end

  context 'with a real module that is built' do
    include_context 'with module source'

    let(:tarball_name) do
      builder = described_class.new(module_source, output_dir, nil)
      builder.build
    end

    it 'builds the module and returns the path to the tarball' do
      expect(tarball_name).to start_with(output_dir)
    end

    context 'which is installed via Puppet' do
      let(:extract_path) { Dir.mktmpdir }
      let(:extracted_module_path) { File.join(extract_path, Dir.entries(extract_path).reject { |p| %w[. ..].include?(p) }.first) }

      RSpec::Matchers.define :be_an_empty_glob do
        match do |actual|
          Dir.glob(extracted_module_path + actual).empty?
        end

        failure_message do |actual|
          "expected that #{actual} would be empty but got #{Dir.glob(extracted_module_path + actual)}"
        end
      end

      RSpec::Matchers.define :be_identical_as_source do
        match do |actual|
          # Dir.glob(..., base: xxx) does not work, so need to use a crude method to get the relative directory path
          @source = Dir.glob(module_source + actual).map { |p| p.slice(module_source.length..-1) }
          @extracted = Dir.glob(extracted_module_path + actual).map { |p| p.slice(extracted_module_path.length..-1) }

          @matcher = RSpec::Matchers::BuiltIn::ContainExactly.new(@source)
          @matcher.matches?(@extracted)
        end

        failure_message do
          @matcher.failure_message
        end
      end

      before(:each) do
        # Force the module to be built...
        built_tarball = tarball_name
        puts "built_tarball: #{built_tarball}"

        # Use puppet to "install" it...
        require 'open3'
        command = "puppet module install --force --ignore-dependencies --target-dir #{extract_path} --verbose #{built_tarball}"
        puts command
        output, status = Open3.capture2e(command)

        raise "Failed to install the module using Puppet. Exit code #{status.exitstatus}: #{output}" unless status.exitstatus.zero?
        raise 'Failed to install the module using Puppet. Missing extract directory' if extracted_module_path.nil?
      end

      after(:each) do
        puts "extract_path: #{extract_path}"
        # FileUtils.rm_rf(extract_path) if Dir.exist?(extract_path)
      end

      it 'expands the expected paths' do # rubocop:disable RSpec/MultipleExpectations This is expected
        # No development directories
        expect('/spec/*').to be_an_empty_glob
        expect('/.vscode/*').to be_an_empty_glob
        expect('/tmp/*').to be_an_empty_glob
        # No development files
        expect('/.fixtures').to be_an_empty_glob
        expect('/.gitignore').to be_an_empty_glob
        expect('/Rakefile').to be_an_empty_glob
        # No CI files
        expect('/.travis.yml').to be_an_empty_glob
        expect('/appveyor.yml').to be_an_empty_glob

        # Important Extracted files
        expect('/manifests/**/*').to be_identical_as_source
        expect('/templates/**/*').to be_identical_as_source
        expect('/lib/**/*').to be_identical_as_source
      end
    end
  end
end
