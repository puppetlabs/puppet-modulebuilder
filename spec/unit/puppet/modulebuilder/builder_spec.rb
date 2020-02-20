# frozen_string_literal: true

require 'spec_helper'
require 'puppet/modulebuilder/builder'

RSpec.describe Puppet::Modulebuilder::Builder do
  subject(:builder) { described_class.new(module_source, module_dest, logger) }

  let(:module_source) { File.join(root_dir, 'path', 'to', 'module') }
  let(:module_dest) { nil }
  let(:logger) { nil }
  let(:root_dir) { Gem.win_platform? ? 'C:/' : '/' }

  before(:each) do
    # Mock that the module source exists
    allow(builder).to receive(:file_directory?).with(module_source).and_return(true)
    allow(builder).to receive(:file_readable?).with(module_source).and_return(true)
  end

  shared_context 'with mock metadata' do |metadata_content|
    before(:each) do
      content = metadata_content.nil? ? "{\"name\": \"my-module\",\n\"version\": \"0.1.0\"}" : metadata_content
      allow(builder).to receive(:file_exists?).with(%r{metadata\.json}).and_return(true)
      allow(builder).to receive(:file_readable?).with(%r{metadata\.json}).and_return(true)
      allow(builder).to receive(:read_file).with(%r{metadata\.json}).and_return(content)
    end
  end

  describe '#initialize' do
    context 'when the source does not exist' do
      it do
        allow(builder).to receive(:file_directory?).with(module_source).and_return(false)
        expect { builder.source }.to raise_error(ArgumentError, %r{does not exist})
      end
    end

    context 'with an invalid logger' do
      it do
        expect { described_class.new(module_source, module_dest, [123]) }.to raise_error(ArgumentError, %r{logger is expected to})
      end
    end

    context 'with a real logger' do
      it do
        expect { described_class.new(module_source, module_dest, Logger.new($stdout)) }.not_to raise_error
      end
    end

    context 'by default' do
      it 'remembers the source' do
        expect(builder.source).to eq(module_source)
      end

      it 'sets the destination to <source>/pkg' do
        expect(builder.destination).to eq(File.join(module_source, 'pkg'))
      end
    end

    context 'with a specified destination' do
      let(:module_dest) { '/some/exotic/destination' }

      it 'remembers the destination' do
        expect(builder.destination).to eq(module_dest)
      end
    end
  end

  describe '#metadata' do
    subject(:metadata) { builder.metadata }

    include_context 'with mock metadata', "{\"name\": \"my-module\",\n\"version\": \"0.1.0\"}"

    it { is_expected.to be_a(Hash) }
    it { is_expected.to include('name' => 'my-module', 'version' => '0.1.0') }
  end

  describe '#package_file' do
    subject(:package_file) { builder.package_file }

    let(:module_dest) { File.join(root_dir, 'tmp') }

    include_context 'with mock metadata'

    it { is_expected.to eq(File.join(module_dest, 'my-module-0.1.0.tar.gz')) }
  end

  describe '#build_dir' do
    subject(:build_dir) { builder.build_dir }

    let(:module_dest) { File.join(root_dir, 'tmp') }

    include_context 'with mock metadata'

    it { is_expected.to eq(File.join(module_dest, 'my-module-0.1.0')) }
  end

  describe '#stage_module_in_build_dir' do
    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }

    before(:each) do
      require 'pathspec'
      allow(builder).to receive(:ignored_files).and_return(PathSpec.new("/spec/\n"))
      require 'find'
      allow(Find).to receive(:find).with(module_source).and_yield(found_file)
    end

    after(:each) do
      builder.stage_module_in_build_dir
    end

    context 'when it finds a non-ignored path' do
      let(:found_file) { File.join(module_source, 'metadata.json') }

      it 'stages the path into the build directory' do
        expect(builder).to receive(:stage_path).with(found_file)
      end
    end

    context 'when it finds an ignored path' do
      let(:found_file) { File.join(module_source, 'spec', 'spec_helper.rb') }

      it 'does not stage the path' do
        require 'find'
        expect(Find).to receive(:prune)
        expect(builder).not_to receive(:stage_path).with(found_file)
      end
    end

    context 'when it finds the module directory itself' do
      let(:found_file) { module_source }

      it 'does not stage the path' do
        expect(builder).not_to receive(:stage_path).with(module_source)
      end
    end
  end

  describe '#stage_path' do
    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }
    let(:path_to_stage) { File.join(module_source, 'test') }
    let(:path_in_build_dir) { File.join(module_source, 'pkg', release_name, 'test') }
    let(:release_name) { 'my-module-0.0.1' }

    before(:each) do
      allow(builder).to receive(:release_name).and_return(release_name)
    end

    context 'when the path contains non-ASCII characters' do
      RSpec.shared_examples 'a failing path' do |relative_path|
        let(:path) do
          File.join(module_source, relative_path).force_encoding(Encoding.find('filesystem')).encode('utf-8', invalid: :replace)
        end

        before(:each) do
          allow(builder).to receive(:file_directory?).with(path).and_return(true)
          allow(builder).to receive(:file_symlink?).with(path).and_return(false)
          allow(builder).to receive(:fileutils_cp).with(path, anything, anything).and_return(true)
        end

        it do
          expect {
            builder.stage_path(path)
          }.to raise_error(ArgumentError, %r{can only include ASCII characters})
        end
      end

      include_examples 'a failing path', "strange_unicode_\u{000100}"
      include_examples 'a failing path', "\300\271to"
    end

    context 'when the path is a directory' do
      before(:each) do
        allow(builder).to receive(:file_directory?).with(path_to_stage).and_return(true)
        allow(builder).to receive(:file_stat).with(path_to_stage).and_return(instance_double(File::Stat, mode: 0o100755))
      end

      it 'creates the directory in the build directory' do
        expect(builder).to receive(:fileutils_mkdir_p).with(path_in_build_dir, mode: 0o100755)
        builder.stage_path(path_to_stage)
      end
    end

    context 'when the path is a symlink' do
      before(:each) do
        allow(builder).to receive(:file_directory?).with(path_to_stage).and_return(false)
        allow(builder).to receive(:file_symlink?).with(path_to_stage).and_return(true)
      end

      it 'warns the user about the symlink and skips over it' do
        expect(builder).to receive(:warn_symlink).with(path_to_stage)
        expect(builder).not_to receive(:fileutils_mkdir_p).with(any_args)
        expect(builder).not_to receive(:fileutils_cp).with(any_args)
        builder.stage_path(path_to_stage)
      end
    end

    context 'when the path is a regular file' do
      before(:each) do
        allow(builder).to receive(:file_directory?).with(path_to_stage).and_return(false)
        allow(builder).to receive(:file_symlink?).with(path_to_stage).and_return(false)
      end

      it 'copies the file into the build directory, preserving the permissions' do
        expect(builder).to receive(:fileutils_cp).with(path_to_stage, path_in_build_dir, preserve: true)
        builder.stage_path(path_to_stage)
      end

      context 'when the path is too long' do
        let(:path_to_stage) { File.join(*['thing'] * 30) }

        it do
          expect {
            builder.stage_path(path_to_stage)
          }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#path_too_long?' do
    good_paths = [
      File.join('a' * 155, 'b' * 100),
      File.join('a' * 151, *['qwer'] * 19, 'bla'),
      File.join('/', 'a' * 49, 'b' * 50),
      File.join('a' * 49, "#{'b' * 50}x"),
      File.join("#{'a' * 49}x", 'b' * 50),
    ]

    bad_paths = {
      File.join('a' * 152, 'b' * 11, 'c' * 93) => %r{longer than 256}i,
      File.join('a' * 152, 'b' * 10, 'c' * 92) => %r{could not be split}i,
      File.join('a' * 162, 'b' * 10) => %r{could not be split}i,
      File.join('a' * 10, 'b' * 110) => %r{could not be split}i,
      'a' * 114 => %r{could not be split}i,
    }

    good_paths.each do |path|
      describe "the path '#{path}'" do
        it { expect { builder.validate_ustar_path!(path) }.not_to raise_error }
      end
    end

    bad_paths.each do |path, err|
      describe "the path '#{path}'" do
        it { expect { builder.validate_ustar_path!(path) }.to raise_error(ArgumentError, err) }
      end
    end
  end

  describe '#validate_path_encoding!' do
    context 'when passed a path containing only ASCII characters' do
      it do
        expect {
          builder.validate_path_encoding!(File.join('path', 'to', 'file'))
        }.not_to raise_error
      end
    end

    context 'when passed a path containing non-ASCII characters' do
      it do
        expect {
          builder.validate_path_encoding!(File.join('path', "\330\271to", 'file'))
        }.to raise_error(ArgumentError, %r{can only include ASCII characters})
      end
    end
  end

  describe '#ignored_path?' do
    let(:ignore_patterns) do
      [
        '/vendor/',
        'foo',
      ]
    end
    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }

    before(:each) do
      require 'pathspec'
      allow(builder).to receive(:ignored_files).and_return(PathSpec.new(ignore_patterns.join("\n")))
    end

    it 'returns false for paths not matched by the patterns' do
      expect(builder.ignored_path?(File.join(module_source, 'bar'))).to be_falsey
    end

    it 'returns true for paths matched by the patterns' do
      expect(builder.ignored_path?(File.join(module_source, 'foo'))).to be_truthy
    end

    it 'returns true for children of ignored parent directories' do
      expect(builder.ignored_path?(File.join(module_source, 'vendor', 'test'))).to be_truthy
    end
  end

  describe '#ignore_file' do
    subject { builder.ignore_file }

    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }
    let(:possible_files) do
      [
        '.pdkignore',
        '.pmtignore',
        '.gitignore',
      ]
    end
    let(:available_files) { [] }

    before(:each) do
      available_files.each do |file|
        file_path = File.join(module_source, file)

        allow(builder).to receive(:file_exists?).with(file_path).and_return(true)
        allow(builder).to receive(:file_readable?).with(file_path).and_return(true)
      end

      (possible_files - available_files).each do |file|
        file_path = File.join(module_source, file)

        allow(builder).to receive(:file_exists?).with(file_path).and_return(false)
        allow(builder).to receive(:file_readable?).with(file_path).and_return(false)
      end
    end

    context 'when none of the possible ignore files are present' do
      it { is_expected.to be_nil }
    end

    context 'when .gitignore is present' do
      let(:available_files) { ['.gitignore'] }

      it 'returns the path to the .gitignore file' do
        is_expected.to eq(File.join(module_source, '.gitignore'))
      end

      context 'and .pmtignore is present' do
        let(:available_files) { ['.gitignore', '.pmtignore'] }

        it 'returns the path to the .pmtignore file' do
          is_expected.to eq(File.join(module_source, '.pmtignore'))
        end

        context 'and .pdkignore is present' do
          let(:available_files) { possible_files }

          it 'returns the path to the .pdkignore file' do
            is_expected.to eq(File.join(module_source, '.pdkignore'))
          end
        end
      end
    end
  end

  describe '#ignored_files' do
    subject { builder.ignored_files }

    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }

    before(:each) do
      require 'pathspec'
      allow(File).to receive(:realdirpath) { |path| path }
    end

    context 'when no ignore file is present in the module' do
      before(:each) do
        allow(builder).to receive(:ignore_file).and_return(nil)
      end

      it 'returns a PathSpec object with the target dir' do
        is_expected.to be_a(PathSpec)
        is_expected.not_to be_empty
        is_expected.to match('pkg/')
      end
    end

    context 'when an ignore file is present in the module' do
      before(:each) do
        ignore_file_path = File.join(module_source, '.pdkignore')
        ignore_file_content = "/vendor/\n"

        allow(builder).to receive(:ignore_file).and_return(ignore_file_path)
        allow(builder).to receive(:read_file).with(ignore_file_path, anything).and_return(ignore_file_content)
      end

      it 'returns a PathSpec object populated by the ignore file' do
        is_expected.to be_a(PathSpec)
        is_expected.to have_attributes(specs: array_including(an_instance_of(PathSpec::GitIgnoreSpec)))
      end
    end
  end
end
