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

    before do
      # Copy the module to the temporary directory
      FileUtils.cp_r(File.join(FIXTURES_DIR, 'module'), tmp_dir)

      # prepare a symlink pointing to the module. All module builder functions should work on symlinks.
      # See https://github.com/puppetlabs/puppet_litmus/pull/301 for background
      FileUtils.ln_s(module_source_actual, module_source)
    end

    after do
      FileUtils.rm_rf(tmp_dir)
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
      let(:extracted_module_path) { Dir[File.join(extract_path, '*')].first }

      RSpec::Matchers.define :be_an_empty_glob do
        match do |actual|
          @extracted = Dir.glob(actual, base: extracted_module_path)
          @extracted.empty?
        end

        failure_message do |actual|
          "expected that #{actual} would be empty but got #{@extracted}"
        end
      end

      RSpec::Matchers.define :be_identical_as_soource do
        match do |actual|
          @source = Dir.glob(actual, base: module_source)
          @extracted = Dir.glob(actual, base: extracted_module_path)

          @source == @extracted
        end

        failure_message do
          "expected #{@source} but got #{@extracted}"
        end
      end

      before do
        # Force the module to be built...
        built_tarball = tarball_name

        # Use puppet to "install" it...
        require 'open3'
        output, status = Open3.capture2e("bundle exec puppet module install --force --ignore-dependencies --target-dir #{extract_path} --verbose #{built_tarball}")

        raise "Failed to install the module using Puppet. Exit code #{status.exitstatus}: #{output}" unless status.exitstatus.zero?
        raise 'Failed to install the module using Puppet. Missing extract directory' if extracted_module_path.nil?
      end

      after do
        FileUtils.rm_rf(extract_path)
      end

      it 'expands the expected paths' do # This is expected
        # No development directories
        expect('spec/*').to be_an_empty_glob
        expect('.vscode/*').to be_an_empty_glob
        expect('tmp/*').to be_an_empty_glob
        # No development files
        expect('.fixtures').to be_an_empty_glob
        expect('.gitignore').to be_an_empty_glob
        expect('Rakefile').to be_an_empty_glob
        # No CI files
        expect('.travis.yml').to be_an_empty_glob
        expect('appveyor.yml').to be_an_empty_glob

        # Important Extracted files
        expect('manifests/*').to be_identical_as_soource
        expect('templates/*').to be_identical_as_soource
        expect('lib/*').to be_identical_as_soource
      end
    end
  end
end
