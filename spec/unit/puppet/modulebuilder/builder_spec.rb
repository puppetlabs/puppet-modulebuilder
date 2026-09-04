# frozen_string_literal: true

require 'spec_helper'
require 'puppet/modulebuilder/builder'

RSpec.describe Puppet::Modulebuilder::Builder do
  subject(:builder) { described_class.new(module_source, module_dest, logger) }

  let(:module_source) { File.join(root_dir, 'path', 'to', 'module') }
  let(:module_dest) { nil }
  let(:logger) { nil }
  let(:root_dir) { Gem.win_platform? ? 'C:/' : '/' }

  before do
    # Mock that the module source exists
    allow(builder).to receive(:file_directory?).with(module_source).and_return(true)
    allow(builder).to receive(:file_readable?).with(module_source).and_return(true)
    allow(File).to receive(:realpath).with(module_source).and_return(module_source)
  end

  shared_context 'with mock metadata' do |metadata_content|
    before do
      content = metadata_content.nil? ? "{\"name\": \"my-module\",\n\"version\": \"0.1.0\"}" : metadata_content
      allow(builder).to receive(:file_exists?).with(/metadata\.json/).and_return(true)
      allow(builder).to receive(:file_readable?).with(/metadata\.json/).and_return(true)
      allow(builder).to receive(:read_file).with(/metadata\.json/).and_return(content)
    end
  end

  describe '#initialize' do
    context 'when the source does not exist' do
      it do
        result = builder
        allow(result).to receive(:file_directory?).with(module_source).and_return(false)
        expect { result.source }.to raise_error(ArgumentError, /does not exist/)
      end
    end

    context 'when the source is not readable' do
      it do
        result = builder
        allow(result).to receive(:file_readable?).with(module_source).and_return(false)
        expect { result.source }.to raise_error(ArgumentError, /does not exist/)
      end
    end

    context 'with an invalid logger' do
      it do
        expect do
          described_class.new(module_source, module_dest, [123])
        end.to raise_error(ArgumentError, /logger is expected to/)
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

    context 'when metadata.json does not exist' do
      before do
        allow(builder).to receive(:file_exists?).with(/metadata\.json/).and_return(false)
      end

      it 'raises an error' do
        expect { builder.metadata }.to raise_error(ArgumentError, /does not exist/)
      end
    end

    context 'when metadata.json is not readable' do
      before do
        allow(builder).to receive(:file_exists?).with(/metadata\.json/).and_return(true)
        allow(builder).to receive(:file_readable?).with(/metadata\.json/).and_return(false)
      end

      it 'raises an error' do
        expect { builder.metadata }.to raise_error(ArgumentError, /Unable to open/)
      end
    end

    context 'when metadata.json contains invalid JSON' do
      before do
        allow(builder).to receive(:file_exists?).with(/metadata\.json/).and_return(true)
        allow(builder).to receive(:file_readable?).with(/metadata\.json/).and_return(true)
        allow(builder).to receive(:read_file).with(/metadata\.json/).and_return('{not: valid}')
      end

      it 'raises an error' do
        expect { builder.metadata }.to raise_error(ArgumentError, /Invalid JSON/)
      end
    end

    context 'when called more than once' do
      it 'only reads the file once' do
        expect(builder).to receive(:read_file).with(/metadata\.json/).once.and_return("{\"name\": \"my-module\",\n\"version\": \"0.1.0\"}")
        2.times { builder.metadata }
      end
    end
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

    before do
      require 'pathspec'
      allow(builder).to receive(:ignored_files).and_return(PathSpec.new("/spec/\n"))
      require 'find'
      allow(Find).to receive(:find).with(module_source).and_yield(found_file)
      allow(builder).to receive(:file_directory?).with(found_file).and_return(false) if found_file != module_source
      allow(builder).to receive(:copy_mtime).with(module_source)
    end

    after do
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

    before do
      builder.release_name = release_name
    end

    context 'when the path contains non-ASCII characters' do
      RSpec.shared_examples 'a failing path' do |relative_path|
        let(:path) do
          File.join(module_source, relative_path).force_encoding(Encoding.find('filesystem')).encode('utf-8',
                                                                                                     invalid: :replace)
        end

        before do
          allow(builder).to receive(:file_directory?).with(path).and_return(true)
          allow(builder).to receive(:file_symlink?).with(path).and_return(false)
          allow(builder).to receive(:fileutils_cp).with(path, anything, anything).and_return(true)
        end

        it do
          expect do
            builder.stage_path(path)
          end.to raise_error(ArgumentError, /can only include ASCII characters/)
        end
      end

      include_examples 'a failing path', "strange_unicode_\u{000100}"
      include_examples 'a failing path', "\300\271to"
    end

    context 'when the path is a directory' do
      before do
        allow(builder).to receive(:file_directory?).with(path_to_stage).and_return(true)
        allow(builder).to receive(:file_stat).with(path_to_stage).and_return(instance_double(File::Stat,
                                                                                             mode: 0o100755))
      end

      it 'creates the directory in the build directory' do
        expect(builder).to receive(:fileutils_mkdir_p).with(path_in_build_dir, mode: 0o100755)
        builder.stage_path(path_to_stage)
      end
    end

    context 'when the path is a symlink' do
      before do
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
      before do
        allow(builder).to receive(:file_directory?).with(path_to_stage).and_return(false)
        allow(builder).to receive(:file_symlink?).with(path_to_stage).and_return(false)
      end

      it 'copies the file into the build directory, preserving the permissions' do
        expect(builder).to receive(:fileutils_cp).with(path_to_stage, path_in_build_dir, preserve: true)
        builder.stage_path(path_to_stage)
      end

      context 'when the path is too long' do
        let(:path_to_stage) { File.join(module_source, File.join(*['thing'] * 300)) }

        it do
          expect do
            builder.stage_path(path_to_stage)
          end.to raise_error(RuntimeError, /longer than 256.*Rename the file or exclude it from the package/)
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
      File.join('a' * 152, 'b' * 11, 'c' * 93) => /longer than 256/i,
      File.join('a' * 152, 'b' * 10, 'c' * 92) => /could not be split/i,
      File.join('a' * 162, 'b' * 10) => /could not be split/i,
      File.join('a' * 10, 'b' * 110) => /could not be split/i,
      'a' * 114 => /could not be split/i,
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
        expect do
          builder.validate_path_encoding!(File.join('path', 'to', 'file'))
        end.not_to raise_error
      end
    end

    context 'when passed a path containing non-ASCII characters' do
      it do
        expect do
          builder.validate_path_encoding!(File.join('path', "\330\271to", 'file'))
        end.to raise_error(ArgumentError, /can only include ASCII characters/)
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

    before do
      require 'pathspec'
      allow(builder).to receive(:ignored_files).and_return(PathSpec.new(ignore_patterns.join("\n")))
    end

    it 'returns false for paths not matched by the patterns' do
      expect(builder).not_to be_ignored_path(File.join(module_source, 'bar'))
    end

    it 'returns true for paths matched by the patterns' do
      expect(builder).to be_ignored_path(File.join(module_source, 'foo'))
    end

    it 'returns true for children of ignored parent directories' do
      expect(builder).to be_ignored_path(File.join(module_source, 'vendor', 'test'))
    end
  end

  describe '#ignored_files' do
    subject { builder.ignored_files }

    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }

    before do
      require 'pathspec'
      allow(File).to receive(:realdirpath) { |path| path }
    end

    context 'when no ignore file is present in the module' do
      before do
        allow(builder).to receive(:ignore_file).and_return(nil)
      end

      it 'returns a PathSpec object with the target dir' do
        expect(subject).to be_a(PathSpec)
        expect(subject).not_to be_empty
        expect(subject).to match('pkg/')
      end
    end

    context 'when an ignore file is present in the module' do
      before do
        ignore_file_path = File.join(module_source, '.pdkignore')
        ignore_file_content = "/vendor/\n"

        allow(builder).to receive(:ignore_file).and_return(ignore_file_path)
        allow(builder).to receive(:read_file).with(ignore_file_path, anything).and_return(ignore_file_content)
      end

      it 'returns a PathSpec object populated by the ignore file' do
        expect(subject).to be_a(PathSpec)
        expect(subject).to have_attributes(specs: array_including(an_instance_of(PathSpec::GitIgnoreSpec)))
      end
    end

    context 'when the destination is outside the module source' do
      let(:module_dest) { File.join(root_dir, 'other', 'destination') }

      it 'does not add the destination to the ignore list' do
        expect(subject.specs.map(&:pattern)).not_to include('/destination/')
      end
    end
  end

  describe '#warn_symlink' do
    let(:symlink_path) { instance_double(Pathname, 'symlink_path') }
    let(:module_path) { instance_double(Pathname, 'module_path') }
    let(:realpath) { instance_double(Pathname, 'realpath') }

    it 'warns' do
      allow(Pathname).to receive(:new).with('/tmp/foo').and_return(symlink_path)
      allow(Pathname).to receive(:new).with('/path/to/module').and_return(module_path)
      allow(Pathname).to receive(:new).with('C:/path/to/module').and_return(module_path)
      allow(symlink_path).to receive(:relative_path_from).with(module_path).and_return('/symlink_path')
      allow(symlink_path).to receive(:realpath).with(no_args).and_return(realpath)
      allow(realpath).to receive(:relative_path_from).with(module_path).and_return('/realpath')

      expect(builder.logger).to receive(:warn).with('Symlinks in modules are not supported and will not be included in the package. Please investigate symlink /symlink_path -> /realpath.')
      expect(builder.warn_symlink('/tmp/foo')).to be_nil
    end
  end

  describe '#build' do
    include_context 'with mock metadata'

    before do
      allow(builder).to receive(:create_build_dir)
      allow(builder).to receive(:stage_module_in_build_dir)
      allow(builder).to receive(:build_package)
      allow(builder).to receive(:cleanup_build_dir)
    end

    it 'creates the build dir, stages the module, builds the package and returns the package file' do
      expect(builder).to receive(:create_build_dir).ordered
      expect(builder).to receive(:stage_module_in_build_dir).ordered
      expect(builder).to receive(:build_package).ordered
      expect(builder.build).to eq(builder.package_file)
    end

    it 'cleans up the build directory even when an error is raised' do
      allow(builder).to receive(:stage_module_in_build_dir).and_raise(RuntimeError, 'build failed')
      expect(builder).to receive(:cleanup_build_dir)
      expect { builder.build }.to raise_error(RuntimeError, 'build failed')
    end
  end

  describe '#create_build_dir' do
    include_context 'with mock metadata'

    it 'cleans up and then creates the build directory' do
      expect(builder).to receive(:cleanup_build_dir).ordered
      expect(builder).to receive(:fileutils_mkdir_p).with(builder.build_dir).ordered
      builder.create_build_dir
    end
  end

  describe '#cleanup_build_dir' do
    include_context 'with mock metadata'

    it 'removes the build directory recursively' do
      expect(FileUtils).to receive(:rm_rf).with(builder.build_dir, secure: true)
      builder.cleanup_build_dir
    end
  end

  describe '#package_already_exists?' do
    include_context 'with mock metadata'

    context 'when the package file already exists' do
      before do
        allow(builder).to receive(:file_exists?).with(builder.package_file).and_return(true)
      end

      it { expect(builder.package_already_exists?).to be(true) }
    end

    context 'when the package file does not exist' do
      before do
        allow(builder).to receive(:file_exists?).with(builder.package_file).and_return(false)
      end

      it { expect(builder.package_already_exists?).to be(false) }
    end
  end

  describe '#copy_mtime' do
    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }
    let(:path) { File.join(module_source, 'manifests') }
    let(:mtime) { Time.now }
    let(:release_name) { 'my-module-0.0.1' }

    before do
      builder.release_name = release_name
      allow(builder).to receive(:file_stat).with(path).and_return(instance_double(File::Stat, mtime: mtime))
    end

    it 'touches the destination path with the source mtime' do
      dest_path = File.join(builder.build_dir, 'manifests')
      expect(builder).to receive(:fileutils_touch).with(dest_path, mtime: mtime)
      builder.copy_mtime(path)
    end

    context 'when the path contains non-ASCII characters' do
      let(:path) { File.join(module_source, "\330\271to") }

      it 'raises an ArgumentError' do
        expect { builder.copy_mtime(path) }.to raise_error(ArgumentError, /can only include ASCII characters/)
      end
    end
  end

  describe '#stage_module_in_build_dir with directories' do
    let(:module_source) { File.join(root_dir, 'tmp', 'my-module') }
    let(:subdir) { File.join(module_source, 'manifests') }

    before do
      require 'pathspec'
      require 'find'
      allow(builder).to receive(:ignored_files).and_return(PathSpec.new("/spec/\n"))
      allow(Find).to receive(:find).with(module_source).and_yield(subdir)
      allow(builder).to receive(:file_directory?).with(subdir).and_return(true)
      allow(builder).to receive(:stage_path).with(subdir)
      allow(builder).to receive(:copy_mtime)
    end

    it 'resets mtime for the source directory and any staged subdirectories' do
      expect(builder).to receive(:copy_mtime).with(module_source)
      expect(builder).to receive(:copy_mtime).with(subdir)
      builder.stage_module_in_build_dir
    end
  end

  describe '#build_package' do
    include_context 'with mock metadata'

    let(:module_dest) { File.join(root_dir, 'tmp') }
    let(:build_dir_name) { builder.build_context[:build_dir_name] }
    let(:mock_tar) { instance_double(Minitar::Output) }
    let(:mock_stat) { instance_double(File::Stat, mode: 0o100644) }

    before do
      require 'zlib'
      require 'minitar'
      require 'find'

      mock_gz   = instance_double(Zlib::GzipWriter)
      mock_file = instance_double(File)

      allow(FileUtils).to receive(:rm_f).with(builder.package_file)
      allow(Dir).to receive(:chdir).with(builder.destination).and_yield
      allow(File).to receive(:open).with(builder.package_file, 'wb').and_return(mock_file)
      allow(Zlib::GzipWriter).to receive(:new).with(mock_file).and_return(mock_gz)
      allow(Minitar::Output).to receive(:new).with(mock_gz).and_return(mock_tar)
      allow(Find).to receive(:find).with(build_dir_name).and_yield(build_dir_name)
      allow(File).to receive(:stat).with(build_dir_name).and_return(mock_stat)
      allow(Minitar).to receive(:dir?).with(build_dir_name).and_return(true)
      allow(Minitar).to receive(:pack_file).with(anything, mock_tar)
      allow(mock_tar).to receive(:close)
    end

    it 'removes any existing package file before building' do
      expect(FileUtils).to receive(:rm_f).with(builder.package_file)
      builder.build_package
    end

    it 'packs entries into the tarball' do
      expect(Minitar).to receive(:pack_file).with(hash_including(name: build_dir_name), mock_tar)
      builder.build_package
    end

    it 'ensures the tar is closed' do
      expect(mock_tar).to receive(:close)
      builder.build_package
    end

    context 'when an entry has insufficient permissions' do
      let(:mock_stat) { instance_double(File::Stat, mode: 0o100600) }

      it 'upgrades the entry mode and logs a debug message' do
        expect(builder.logger).to receive(:debug).with(/Updated permissions/)
        builder.build_package
      end
    end
  end

  describe '#read_file (private)' do
    context 'when nil_on_error is true and reading fails' do
      it 'returns nil instead of raising' do
        allow(File).to receive(:read).and_raise(StandardError, 'disk error')
        expect(builder.send(:read_file, '/nonexistent', nil_on_error: true)).to be_nil
      end
    end

    context 'when nil_on_error is false (default) and reading fails' do
      it 'raises the error' do
        allow(File).to receive(:read).and_raise(StandardError, 'disk error')
        expect { builder.send(:read_file, '/nonexistent') }.to raise_error(StandardError, 'disk error')
      end
    end
  end
end
