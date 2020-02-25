# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'puppet/modulebuilder/builder'
require 'tmpdir'

RSpec.describe Puppet::Modulebuilder::Builder do
  RSpec.shared_context 'with module source' do
    let(:tmp_module_dir) { Dir.mktmpdir }
    let(:module_source) { File.join(tmp_module_dir, File.basename(MODULE_FIXTURE)) }

    before(:each) do
      # Copy the module
      FileUtils.cp_r(MODULE_FIXTURE, tmp_module_dir)
    end

    after(:each) do
      FileUtils.rm_rf(tmp_module_dir) if Dir.exist?(tmp_module_dir)
    end
  end

  let(:logger) { nil }

  context 'with a real module that is built' do
    include_context 'with module source'

    let(:tarball_name) do
      builder = described_class.new(module_source, tmp_module_dir, nil)
      builder.build
    end

    it 'builds the module and returns the path to the tarball' do
      expect(tarball_name).to match(%r{#{tmp_module_dir}})
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

      RSpec::Matchers.define :be_identical_as_soource do
        match do |actual|
          # Dir.glob(..., base: xxx) does not work, so need to use a crude method to get the relative directory path
          @source = Dir.glob(module_source + actual).map { |p| p.slice(module_source.length..-1) }
          @extracted = Dir.glob(extracted_module_path + actual).map { |p| p.slice(extracted_module_path.length..-1) }

          @source == @extracted
        end

        failure_message do
          "expected #{@source} but got #{@extracted}"
        end
      end

      before(:each) do
        # Force the module to be built...
        built_tarball = tarball_name

        # Use puppet to "install" it...
        require 'open3'
        output, status = Open3.capture2e("puppet module install --force --ignore-dependencies --target-dir #{extract_path} --verbose #{built_tarball}")

        raise "Failed to install the module using Puppet. Exit code #{status.exitstatus}: #{output}" unless status.exitstatus.zero?
        raise 'Failed to install the module using Puppet. Missing extract directory' if extracted_module_path.nil?
      end

      after(:each) do
        FileUtils.rm_rf(extract_path) if Dir.exist?(extract_path)
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
        expect('/manifests/*').to be_identical_as_soource
        expect('/templates/*').to be_identical_as_soource
        expect('/lib/*').to be_identical_as_soource
      end
    end
  end
end
