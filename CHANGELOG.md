<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v2.0.2](https://github.com/puppetlabs/puppet-modulebuilder/tree/v2.0.2) - 2024-09-24

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v2.0.1...v2.0.2)

### Fixed

- (bug) - Include missing function, facts.d and example dirs in module builds [#102](https://github.com/puppetlabs/puppet-modulebuilder/pull/102) ([jordanbreen28](https://github.com/jordanbreen28))

## [v2.0.1](https://github.com/puppetlabs/puppet-modulebuilder/tree/v2.0.1) - 2024-09-18

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v2.0.0...v2.0.1)

### Fixed

- (bug) - Add lib dir to built modules [#100](https://github.com/puppetlabs/puppet-modulebuilder/pull/100) ([jordanbreen28](https://github.com/jordanbreen28))

## [v2.0.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v2.0.0) - 2024-09-17

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v1.1.0...v2.0.0)

### Changed

- Implement allowlist for puppet module content [#79](https://github.com/puppetlabs/puppet-modulebuilder/pull/79) ([bastelfreak](https://github.com/bastelfreak))

## [v1.1.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v1.1.0) - 2024-09-17

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v1.0.0...v1.1.0)

### Added

- Use Dir.glob with base parameter in acceptance tests [#93](https://github.com/puppetlabs/puppet-modulebuilder/pull/93) ([ekohl](https://github.com/ekohl))

### Fixed

- (CAT-1688) Upgrade rubocop to `~> 1.50.0` [#70](https://github.com/puppetlabs/puppet-modulebuilder/pull/70) ([LukasAud](https://github.com/LukasAud))

## [v1.0.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v1.0.0) - 2023-04-25

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v1.0.0.rc.1...v1.0.0)

## [v1.0.0.rc.1](https://github.com/puppetlabs/puppet-modulebuilder/tree/v1.0.0.rc.1) - 2023-04-18

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v0.3.0...v1.0.0.rc.1)

### Changed

- (CONT-881) Ruby 3 / Puppet 8 Support [#50](https://github.com/puppetlabs/puppet-modulebuilder/pull/50) ([chelnak](https://github.com/chelnak))

## [v0.3.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v0.3.0) - 2021-05-17

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v0.2.1...v0.3.0)

### Added

- Use Puppet 7 in development on Ruby 2.7+ [#32](https://github.com/puppetlabs/puppet-modulebuilder/pull/32) ([ekohl](https://github.com/ekohl))
- Add a setter for release_name [#31](https://github.com/puppetlabs/puppet-modulebuilder/pull/31) ([ekohl](https://github.com/ekohl))
- Preserve directory mtimes [#27](https://github.com/puppetlabs/puppet-modulebuilder/pull/27) ([ekohl](https://github.com/ekohl))
- Use match_path instead of match_paths [#26](https://github.com/puppetlabs/puppet-modulebuilder/pull/26) ([ekohl](https://github.com/ekohl))

### Fixed

- Use correct source variable when warning about symlinks [#36](https://github.com/puppetlabs/puppet-modulebuilder/pull/36) ([DavidS](https://github.com/DavidS))
- Ignore all hidden files in the root dir [#29](https://github.com/puppetlabs/puppet-modulebuilder/pull/29) ([ekohl](https://github.com/ekohl))

## [v0.2.1](https://github.com/puppetlabs/puppet-modulebuilder/tree/v0.2.1) - 2020-06-08

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v0.2.0...v0.2.1)

### Fixed

- (IAC-864) fix symlinked source [#23](https://github.com/puppetlabs/puppet-modulebuilder/pull/23) ([DavidS](https://github.com/DavidS))
- (IAC-859) add Ruby 2.7 testing; address deprecation warnings [#22](https://github.com/puppetlabs/puppet-modulebuilder/pull/22) ([DavidS](https://github.com/DavidS))

## [v0.2.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v0.2.0) - 2020-04-30

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/v0.1.0...v0.2.0)

### Added

- Set defaults for Builder [#11](https://github.com/puppetlabs/puppet-modulebuilder/pull/11) ([ekohl](https://github.com/ekohl))

### Fixed

- Always ignore .git [#15](https://github.com/puppetlabs/puppet-modulebuilder/pull/15) ([ekohl](https://github.com/ekohl))

## [v0.1.0](https://github.com/puppetlabs/puppet-modulebuilder/tree/v0.1.0) - 2020-02-27

[Full Changelog](https://github.com/puppetlabs/puppet-modulebuilder/compare/01ac316defabe60fb7d3c95ec2b219ad5e8e1591...v0.1.0)
