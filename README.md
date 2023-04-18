# Puppet::Modulebuilder

The `puppet-modulebuilder` gem contains the reference implementation for building Puppet modules from source.

## Usage

```ruby
builder = Puppet::Modulebuilder::Builder.new('./puppetlabs-motd', './pkg', nil)
builder.build
```

## Development

To release a new version, update the version number in `version.rb`, run `bundle exec rake changelog` and create a mergeback PR with the results. If that passes, run `bundle exec rake 'release[upstream]'`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/puppet-modulebuilder.
