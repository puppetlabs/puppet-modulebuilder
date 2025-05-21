# frozen_string_literal: true

require 'logger'

module Puppet::Modulebuilder
  # Class to build Puppet Modules from source
  class Builder
    # Due to the way how PathSpec generates the regular expression,
    # `/*` doesn't match directories starting with a dot,
    # so we need `/.*` as well.
    IGNORED = [
      '/**',
      '/.*',
      '!/CHANGELOG*',
      '!/LICENSE',
      '!/README*',
      '!/REFERENCE.md',
      '!/bolt_plugin.json',
      '!/data/**',
      '!/docs/**',
      '!/examples/**',
      '!/facts.d/**',
      '!/files/**',
      '!/functions/**',
      '!/hiera.yaml',
      '!/lib/**',
      '!/locales/**',
      '!/manifests/**',
      '!/metadata.json',
      '!/plans/**',
      '!/scripts/**',
      '!/tasks/**',
      '!/templates/**',
      '!/types/**',
    ].freeze

    attr_reader :destination, :logger

    def initialize(source, destination = nil, logger = nil)
      unless logger.nil? || logger.is_a?(Logger)
        raise ArgumentError,
              format('logger is expected to be nil or a Logger. Got %<klass>s',
                     klass: logger.class)
      end

      @source_validated = false
      @source = source
      @destination = destination.nil? ? File.join(source, 'pkg') : destination
      @logger = logger.nil? ? ::Logger.new(File.open(File::NULL, 'w')) : logger
    end

    # The source to build the module from
    # @return [String]
    def source
      return @source if @source_validated

      validate_source!
      @source = File.realpath(@source)
    end

    # Build a module package from a module directory.
    #
    # @return [String] The path to the built package file.
    def build
      create_build_dir

      stage_module_in_build_dir
      build_package

      package_file
    ensure
      cleanup_build_dir
    end

    # Return the path to the temporary build directory, which will be placed
    # inside the target directory and match the release name
    #
    # @see #release_name
    def build_dir
      @build_dir ||= File.join(build_context[:parent_dir], build_context[:build_dir_name])
    end

    def build_context
      {
        parent_dir: destination,
        build_dir_name: release_name,
      }.freeze
    end

    # Iterate through all the files and directories in the module and stage
    # them into the temporary build directory (unless ignored).
    #
    # @return nil
    def stage_module_in_build_dir
      require 'find'

      directories = [source]

      staged = Find.find(source) do |path|
        next if path == source

        if ignored_path?(path)
          logger.debug("Ignoring #{path} from the build")
          Find.prune
        else
          logger.debug("Staging #{path} for the build")
          directories << path if file_directory?(path)
          stage_path(path)
        end
      end

      # Reset directory mtimes. This must happen after the files have been
      # copied since that modifies a directory's mtime
      directories.each do |directory|
        copy_mtime(directory)
      end

      staged
    end

    # Stage a file or directory from the module into the build directory.
    #
    # @param path [String] The path to the file or directory.
    #
    # @return nil.
    def stage_path(path)
      require 'pathname'

      relative_path = Pathname.new(path).relative_path_from(Pathname.new(source))
      dest_path = File.join(build_dir, relative_path)

      validate_path_encoding!(relative_path.to_path)

      begin
        if file_directory?(path)
          fileutils_mkdir_p(dest_path, mode: file_stat(path).mode)
        elsif file_symlink?(path)
          warn_symlink(path)
        else
          validate_ustar_path!(relative_path.to_path)
          fileutils_cp(path, dest_path, preserve: true)
        end
      rescue ArgumentError => e
        raise format(
          '%<message>s Rename the file or exclude it from the package by adding it to the .pdkignore file in your module.', message: e.message
        )
      end
    end

    def copy_mtime(path)
      require 'pathname'

      relative_path = Pathname.new(path).relative_path_from(Pathname.new(source))
      dest_path = File.join(build_dir, relative_path)

      validate_path_encoding!(relative_path.to_path)

      fileutils_touch(dest_path, mtime: file_stat(path).mtime)
    end

    # Check if the given path matches one of the patterns listed in the
    # ignore file.
    #
    # @param path [String] The path to be checked.
    #
    # @return [Boolean] true if the path matches and should be ignored.
    def ignored_path?(path)
      path = "#{path}/" if File.directory?(path)

      ignored_files.match_path(path, source)
    end

    # Warn the user about a symlink that would have been included in the
    # built package.
    #
    # @param path [String] The relative or absolute path to the symlink.
    #
    # @return nil.
    def warn_symlink(path)
      require 'pathname'

      symlink_path = Pathname.new(path)
      module_path = Pathname.new(source)

      logger.warn format('Symlinks in modules are not supported and will not be included in the package. Please investigate symlink %<from>s -> %<to>s.',
                         from: symlink_path.relative_path_from(module_path), to: symlink_path.realpath.relative_path_from(module_path))
    end

    # Checks if the path contains any non-ASCII characters.
    #
    # Java will throw an error when it encounters a path containing
    # characters that are not supported by the hosts locale. In order to
    # maximise compatibility we limit the paths to contain only ASCII
    # characters, which should be part of any locale character set.
    #
    # @param path [String] the relative path to be added to the tar file.
    #
    # @raise [ArgumentError] if the path contains non-ASCII characters.
    #
    # @return [nil]
    def validate_path_encoding!(path)
      return unless /[^\x00-\x7F]/.match?(path)

      raise ArgumentError, format("'%<path>s' can only include ASCII characters in its path or " \
                                  'filename in order to be compatible with a wide range of hosts.', path: path)
    end

    # Creates a gzip compressed tarball of the build directory.
    #
    # If the destination package already exists, it will be removed before
    # creating the new tarball.
    #
    # @return nil.
    def build_package
      require 'zlib'
      require 'minitar'
      require 'find'

      FileUtils.rm_f(package_file)

      # The chdir necessary us due to Minitar entry not be able to separate the filename
      # within the TAR versus the source filename to pack
      Dir.chdir(build_context[:parent_dir]) do
        gz = Zlib::GzipWriter.new(File.open(package_file, 'wb'))
        begin
          tar = Minitar::Output.new(gz)
          Find.find(build_context[:build_dir_name]) do |entry|
            entry_meta = {
              name: entry,
            }

            orig_mode = File.stat(entry).mode
            min_mode = Minitar.dir?(entry) ? 0o755 : 0o644

            entry_meta[:mode] = orig_mode | min_mode

            if entry_meta[:mode] != orig_mode
              logger.debug(format('Updated permissions of packaged \'%<entry>s\' to %<new_mode>s', entry: entry,
                                                                                                   new_mode: (entry_meta[:mode] & 0o7777).to_s(8)))
            end

            Minitar.pack_file(entry_meta, tar)
          end
        ensure
          tar.close
        end
      end
    end

    # Instantiate a new PathSpec class and populate it with the pattern(s) of
    # files to be ignored.
    #
    # @return [PathSpec] The populated ignore path matcher.
    def ignored_files
      require 'pathspec'

      ignored = PathSpec.new(IGNORED)
      ignored.add("/#{File.basename(destination)}/") if File.realdirpath(destination).start_with?(File.realdirpath(source))

      ignored
    end

    # Create a temporary build directory where the files to be included in
    # the package will be staged before building the tarball.
    #
    # If the directory already exists, remove it first.
    def create_build_dir
      cleanup_build_dir

      fileutils_mkdir_p(build_dir)
    end

    # Remove the temporary build directory and all its contents from disk.
    #
    # @return nil.
    def cleanup_build_dir
      FileUtils.rm_rf(build_dir, secure: true)
    end

    # Read and parse the values from metadata.json for the module that is
    # being built.
    #
    # @return [Hash{String => Object}] The hash of metadata values.
    def metadata
      return @metadata unless @metadata.nil?

      metadata_json_path = File.join(source, 'metadata.json')

      unless file_exists?(metadata_json_path)
        raise ArgumentError,
              format("'%<file>s' does not exist or is not a file.",
                     file: metadata_json_path)
      end

      unless file_readable?(metadata_json_path)
        raise ArgumentError,
              format("Unable to open '%<file>s' for reading.",
                     file: metadata_json_path)
      end

      require 'json'
      begin
        @metadata = JSON.parse(read_file(metadata_json_path))
      rescue JSON::JSONError => e
        raise ArgumentError, format('Invalid JSON in metadata.json: %<msg>s', msg: e.message)
      end
      @metadata.freeze
    end

    # Return the path where the built package file will be written to.
    def package_file
      @package_file ||= File.join(destination, "#{release_name}.tar.gz")
    end

    # Verify if there is an existing package in the target directory and prompts
    # the user if they want to overwrite it.
    def package_already_exists?
      file_exists?(package_file)
    end

    # The release name is used for the build directory and resulting package
    # file.
    #
    # The default combines the module name and version into a Forge-compatible
    # dash separated string. Unless you have an unusual use case this isn't set
    # manually.
    #
    # @return [String]
    def release_name
      @release_name ||= [
        metadata['name'],
        metadata['version'],
      ].join('-')
    end

    attr_writer :release_name

    # Checks if the path length will fit into the POSIX.1-1998 (ustar) tar
    # header format.
    #
    # POSIX.1-2001 (which allows paths of infinite length) was adopted by GNU
    # tar in 2004 and is supported by minitar 0.7 and above.
    #
    # POSIX.1-1998 tar format does not allow for paths greater than 256 bytes,
    # or paths that can't be split into a prefix of 155 bytes (max) and
    # a suffix of 100 bytes (max).
    #
    # This logic was pretty much copied from the private method
    # {Archive::Tar::Minitar::Writer#split_name}.
    #
    # @param path [String] the relative path to be added to the tar file.
    #
    # @raise [ArgumentError] if the path is too long or could not be split.
    #
    # @return [nil]
    def validate_ustar_path!(path)
      raise ArgumentError, format("The path '%<path>s' is longer than 256 bytes.", path: path) if path.bytesize > 256

      if path.bytesize <= 100
        prefix = ''
      else
        parts = path.split(File::SEPARATOR)
        newpath = parts.pop
        nxt = ''

        loop do
          nxt = parts.pop || ''
          break if newpath.bytesize + 1 + nxt.bytesize >= 100

          newpath = File.join(nxt, newpath)
        end

        prefix = File.join(*parts, nxt)
        path = newpath
      end

      return unless path.bytesize > 100 || prefix.bytesize > 155

      raise ArgumentError, \
            format("'%<path>s' could not be split at a directory separator into two " \
                   'parts, the first having a maximum length of 155 bytes and the ' \
                   'second having a maximum length of 100 bytes.', path: path)
    end

    private

    # Validates that source is able to be built
    def validate_source!
      unless file_directory?(@source) && file_readable?(@source)
        raise ArgumentError,
              format("Module source '%<source>s' does not exist as a directory is or is not readable", source: @source)
      end

      @source_validated = true
    end

    # @return [String] The file contents
    def read_file(file, nil_on_error: false, open_args: 'r')
      File.read(file, open_args: Array(open_args))
    rescue StandardError => e
      raise e unless nil_on_error

      nil
    end

    # Filesystem wrapper methods.
    # These are mocked in spec tests.
    def file_exists?(*args)
      File.file?(*args)
    end

    def file_readable?(*args)
      File.readable?(*args)
    end

    def file_directory?(*args)
      File.directory?(*args)
    end

    def file_symlink?(*args)
      File.symlink?(*args)
    end

    def fileutils_cp(src, dest, **options)
      FileUtils.cp(src, dest, **options)
    end

    def fileutils_mkdir_p(dir, **options)
      FileUtils.mkdir_p(dir, **options)
    end

    def fileutils_touch(list, **options)
      FileUtils.touch(list, **options)
    end

    def file_stat(*args)
      File.stat(*args)
    end
  end
end
