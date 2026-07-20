# rubocop-callbacksystems

A RuboCop plugin that enforces the [Callbacksystems Ruby style guide](https://callbacksystems.com)
through a suite of custom cops for Rails applications and Ruby gems.

The cops focus on what RuboCop core and the official plugins do not cover:
naming and structural conventions, declarative style, test discipline, and
patterns that keep code readable as a system grows.

## Installation

```ruby
# Gemfile
gem "rubocop-callbacksystems", require: false
```

Then include the bundled configuration in your `.rubocop.yml`:

```yaml
inherit_gem:
  rubocop-callbacksystems: rubocop.yml
```

That is enough. The plugin auto-loads, enables every Callbacksystems cop, and
configures sensible defaults for the RuboCop core cops, Minitest, Performance,
and Rails plugins.

## Usage

Run RuboCop as usual:

```bash
bundle exec rubocop
```

The bundled `rubocop.yml` enables the full ruleset out of the box. To override
specific cops in your project, declare them after the `inherit_gem` directive
in your `.rubocop.yml`.

## Configuration

All cops live under the `Callbacksystems/` namespace and ship in
[`config/default.yml`](config/default.yml). The defaults are tuned for typical
Rails applications, and most cops scope themselves to `app/`, `lib/`, or `test/`
as appropriate.

### Disabling a cop

```yaml
Callbacksystems/CopName:
  Enabled: false
```

### Adjusting thresholds

Cops that take parameters expose them as standard RuboCop options:

```yaml
Callbacksystems/CopName:
  OptionName: 4
```

Use the real cop names and option keys from
[`config/default.yml`](config/default.yml).

## Cops

This README keeps no per-cop list on purpose, since it drifts out of date too fast.
To see what ships, browse the source: each cop's file under
[`lib/rubocop/cop/callbacksystems/`](lib/rubocop/cop/callbacksystems/) carries an
`@example` block contrasting bad and good code, and
[`config/default.yml`](config/default.yml) lists every cop with its options and
default scope.

## Development

```bash
bin/setup         # install dependencies
bin/test          # run the test suite
bin/rubocop       # self-lint the gem
```

Every cop has a paired test under `test/rubocop/cop/callbacksystems/`. The
helper modules in `lib/rubocop/callbacksystems/helpers/` are tested under
`test/rubocop/callbacksystems/helpers/`.

## Contributing

Bug reports and pull requests are welcome on GitHub. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and conventions.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
