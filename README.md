# rubocop-callbacksystems

Shared RuboCop configuration for Callback Systems projects.

The cops it adds cover what RuboCop core and the official plugins do not: naming
and structural conventions, declarative style, test discipline, and the patterns
that keep code readable as a system grows.

For what any individual cop does, see [the cop reference](docs/README.md).

## Installation

```ruby
# Gemfile
gem "rubocop-callbacksystems", require: false
```

Requires Ruby 4.0 and RuboCop 1.72 or newer.

## Usage

Inherit the bundled configuration in your `.rubocop.yml`:

```yaml
inherit_gem:
  rubocop-callbacksystems: rubocop.yml
```

That is the whole setup. The bundled config declares this gem under `plugins:`,
so RuboCop loads it, enables every Callbacksystems cop, and configures the core
cops along with the Minitest, Performance and Rails plugins. Then run RuboCop as
usual:

```bash
bundle exec rubocop
```

This is one opinionated style, taken whole. To take the cops without it, declare
the plugin yourself and configure them as you like:

```yaml
plugins:
  - rubocop-callbacksystems
```

## Customizing

Override any cop after the `inherit_gem` directive.

```yaml
Callbacksystems/CopName:
  Enabled: false

Callbacksystems/OtherCop:
  MaxOperators: 4
```

Every cop is on by default and lives under the `Callbacksystems/` namespace.
[`config/default.yml`](config/default.yml) is the full list: each cop with its
description, its options and the paths it applies to. Most scope themselves to
`app/`, `lib/` or `test/`.

## Development

```bash
bin/setup                # install dependencies
bin/test                 # run the test suite
bin/rubocop              # the plugin on itself
UPDATE_DOCS=1 bin/test   # regenerate the cop reference and descriptions
```

Every cop has a paired test under `test/rubocop/cop/callbacksystems/`, and the
helper modules under `test/rubocop/callbacksystems/helpers/`.

The cop reference and the `Description:` of each cop in `config/default.yml` are
both generated from the sentence that opens the cop's file, so it is written in
one place and there is nothing to keep in sync. A test fails when either drifts.

## Contributing

Bug reports and pull requests are welcome on GitHub. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
