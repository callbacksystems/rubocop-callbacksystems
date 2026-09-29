# rubocop-callbacksystems

A RuboCop plugin for the Callback Systems Ruby style in Rails applications and Ruby gems. It includes the
`Callbacksystems/` cops and a shared configuration for RuboCop, rubocop-rails, rubocop-performance and rubocop-minitest.

## Installation

You'll need Ruby 4.0 or newer and RuboCop 1.89 or newer. Add the gem to your Gemfile and run `bundle install`:

```ruby
# Gemfile
gem "rubocop-callbacksystems", require: false
```

## Usage

Add the shared configuration to your `.rubocop.yml`:

```yaml
inherit_gem:
  rubocop-callbacksystems: rubocop.yml
```

This loads the plugin, enables every `Callbacksystems/` cop and applies the shared configuration. Run RuboCop with:

```bash
bundle exec rubocop
```

To use the cops with your own RuboCop configuration, load just the plugin:

```yaml
plugins:
  - rubocop-callbacksystems
```

## Cops

Most cops apply to `app/`, `lib/` or `test/`. See [the cop reference](docs/cops.md) for the rules and
[`config/default.yml`](config/default.yml) for their options and paths.

## Active Support

The cops recommend Active Support methods such as `many?`, `excluding`, `squish`, ordinal array readers,
`stringify_keys` and `symbolize_keys`. Rails loads these when it boots. In a plain Ruby application or gem, require
`active_support/all` or the corresponding `active_support/core_ext` files at runtime. Loading the plugin for linting
does not make these methods available in your application.

## Customizing

Override inherited settings in your `.rubocop.yml`:

```yaml
inherit_gem:
  rubocop-callbacksystems: rubocop.yml

Callbacksystems/NoAbbreviations:
  Enabled: false

Callbacksystems/TooManyLocalVariables:
  MaxAssignments: 4
```

## Development

```bash
bundle install
bin/test      # run the test suite
bin/coverage  # run the suite measuring lines, branches and methods
bin/rubocop   # lint the gem with its own cops
bin/docs      # regenerate the cop reference
```

The test suite checks that `docs/cops.md` matches the cops. Run `bin/docs` after changing a cop's documentation.

## License

Released under the [MIT License](LICENSE).
