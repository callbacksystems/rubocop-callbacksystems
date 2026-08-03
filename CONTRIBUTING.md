# Contributing

## Getting set up

```bash
bin/setup
bin/test
bin/rubocop
```

Both have to be green before anything is merged. The plugin lints itself, so the
source has to pass the cops it teaches: if a change fights a cop, that is a
signal about the change, not an obstacle to route around. There are no
`rubocop:disable` comments in this repository and pull requests adding one will
be asked to fix the code instead.

## Adding a cop

1. Write `lib/rubocop/cop/callbacksystems/<name>.rb`. Open the file with a
   comment: one short sentence saying what the cop is for, then a paragraph on
   why it exists, then an `@example` block contrasting bad and good code. That
   first sentence becomes the cop's `Description:` and its row in the reference,
   so it is written once, here.
2. Register it in `config/default.yml` with `Enabled: true`, any options, and
   the paths it applies to.
3. Write `test/rubocop/cop/callbacksystems/<name>_test.rb`. Cover what the cop
   reports, what it deliberately leaves alone, and, if it corrects, what it
   produces.
4. Run `UPDATE_DOCS=1 bin/test` and commit the regenerated `docs/README.md` and
   `config/default.yml`.

## Autocorrection

A cop that corrects has to leave the file it touched correct. Two audits run as
part of the suite and both have to pass:

- **The comment sweep** puts a comment before every line of every shape a cop's
  own tests declare, and fails if the correction drops it or leaves the source
  unparseable.
- **The clash sweep** corrects each shape with the whole cop set at once, the
  way `rubocop -a` does, and fails if the result stops parsing or picks up a
  `Lint` offense it did not have.

If a correction is hard, write it anyway. Refusing to correct a shape is a last
resort, and one to explain in the cop's header when it happens.

## Style

The repository's own conventions are in [CLAUDE.md](CLAUDE.md): small classes
over loose functions, private getters, top-down method order, declarative
naming, and comments only where they explain a non-obvious why.

## Pull requests

Keep a change to one concern, with its tests. Explain what was wrong and why the
change is the right shape, not just what it does.
