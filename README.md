# Puppet::Modulebuilder

[![Code Owners](https://img.shields.io/badge/owners-DevX--team-blue)](https://github.com/puppetlabs/puppet-modulebuilder/blob/main/CODEOWNERS)
![ci](https://github.com/puppetlabs/puppet-modulebuilder/actions/workflows/ci.yml/badge.svg)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/puppetlabs/puppet-modulebuilder)

## Table of Contents

1. [Overview - What is Puppet::Modulebuilder?](#overview)
2. [Description - What does the gem do?](#description)
3. [Usage - How can the gem be used?](#usage)
4. [Testing - How to test changes to the gem?](#contributing)
5. [Contributing - How to contribute to the gem?](#contributing)
6. [Development - How to release changes to the gem?](#development)

## Overview

The `puppet-modulebuilder` gem contains the reference implementation for building Puppet modules from source.

## Description

The purpose of this tool is to take a given local module directory and compile it into a `.tar` file, known as the `tarball`, that can then be installed directly by Puppet on a target machine or uploaded onto the [Puppet Forge](https://forge.puppet.com/) so that it can be accessed publicly.

As part of this process any non-deliverable aspects of the module, parts of it related to the modules development or testing for example, are stripped away leaving only the documentation and the puppet/ruby code that is needed for the module to function.

The parts of the module to be excluded are defined in a `.pdkignore`, `.pmtignore` or `.gitignore` file with the first one to be found in this given order being used. Any directories or files that are listed in the ignore file are then excluded, allowing the user to customize what is and what is not excluded.

## Usage

This gem can be used in one of two ways, the first being to call on it directly as shown in the example below:

```ruby
builder = Puppet::Modulebuilder::Builder.new('./puppetlabs-motd', './pkg', nil)
builder.build
```

For conveniances sake the `puppet-modulebuilder` gem has been included within the `PDK` and as such can be called on to run against a module from within it using the build command as shown below:

```bash
pdk build
```

### Testing

Acceptance tests for this module leverage [puppet_litmus](https://github.com/puppetlabs/puppet_litmus)

```bash
bundle exec rake 'litmus:provision[docker, litmusimage/ubuntu:22.04]'
bundle exec rake 'litmus:install_agent[puppet8-nightly]'
bundle exec rake 'litmus:install_module'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/puppet-modulebuilder.

## Development

To release a new version, simply run the `Release Prep` github action workflow, passing it the desired version, in order to generate a PR containing the necesary changes.

Once this PR is merged you can then run the `Release` action in order to build the gem and push it to [rubygems.org](https://rubygems.org).
