# RuboCop Callbacksystems

Guide for working in this repo. The gem lints itself with its own cops, so the source has to embody the style it enforces.

## What this is

`rubocop-callbacksystems` is a RuboCop plugin for Rails applications and Ruby gems. It ships the cops that live under the `Callbacksystems/` namespace, together with the shareable configuration a project inherits with `inherit_gem`.

`config/default.yml` defines each plugin cop's description, options and paths. Projects inherit `rubocop.yml`, which loads the plugins and configures the core cops and the other plugins the gem depends on.

## Critical rule

**Never disable or adjust a cop to create an exception.** The purpose of this gem is to enforce good programming practices, so when a cop flags the code, fix the code instead of weakening the rule. When a core cop cannot express the rule, write ours and leave the core one off for a stated reason. Its options are not there to be loosened.

## Commands

```bash
bin/test       # the whole suite
bin/coverage   # the suite again, measuring lines, branches and methods
bin/rubocop    # the gem linted by its own cops
bin/docs       # regenerate docs/cops.md
```

After any change, `bin/test` and `bin/rubocop` must both be green. `bin/coverage` requires at least 99% line, branch and method coverage. A new cop needs tests that reach both sides of every condition it reads.

## Layout

`lib/rubocop/cop/callbacksystems/` holds one file per cop, named after the cop in snake_case, defining a class that inherits from `Callbacksystems::Base`.

`lib/rubocop/callbacksystems/` keeps the plugin, `Offense`, helper wiring and the generator behind `bin/docs` at its root. Shared analysis lives in folders matching its namespace:

- `autocorrection/`: rehearsing rewrites and preserving comments.
- `class_structure/`: class bodies, visibility and statement order.
- `execution/`: evaluation order, discarded values and local variables.
- `hashes/`: keyword options and key transformations.
- `helpers/`: shared predicates wired into cops and analysis objects.
- `methods/`: definitions, calls, delegation and reference evidence.
- `project_index/`: Rubydex integration, index lifecycle and analysis across files.
- `source/`: source files, comments, ranges and file checksums.
- `testing/`: analysis of test code, fixtures and source-to-test paths.

`test/` mirrors both implementation trees, including every domain subdirectory. For example, `lib/rubocop/callbacksystems/project_index/reading.rb` is tested by `test/rubocop/callbacksystems/project_index/reading_test.rb`. Move the paired test whenever an implementation moves, and keep direct tests of an extracted object in its own mirror file.

`test/support/` contains the test case classes and shared test infrastructure. `test/test_helper.rb` only boots the environment and loads that support. Checks of the complete plugin, CLI and interactions between cops live in `test/integration/`.

Zeitwerk autoloads and eager loads runtime code under `lib/rubocop`. The documentation generator, `cops_document.rb`, is excluded and loaded explicitly by `bin/docs`. File paths must match their constants without custom inflections.

Name a namespace for its domain, such as `Autocorrection`, `ClassStructure` or `ProjectIndex`, and an object for what it represents. Plurals belong on collections such as `Methods::Definitions`; they are not a directory naming requirement.

## Anatomy of a cop

A header comment opens the file with what the cop is for and why it exists, followed by an `@example` block contrasting the code it rejects with the code it asks for. `lib/rubocop/cop/.rubocop.yml` raises `HeaderMax` on `CommentBlockLength` so those headers can run long.

A small cop can keep its analysis in a few private methods. [PreferMany](lib/rubocop/cop/callbacksystems/prefer_many.rb) shows this shape, including the checks needed before correcting source.

Use an analysis object when the analysis needs state of its own, as in [CommentBlockLength](lib/rubocop/cop/callbacksystems/comment_block_length.rb). The handler passes the object to `report`. The object owns the message because it owns the data the message describes.

### The reporting protocol

An analysis answers `offense` with what it found, or with nothing, and the cop hands it to `report`.

A `RuboCop::Callbacksystems::Offense` carries the range it underlines, the message that names the code it saw and the shape it wants, and an optional correction given as a block. An offense built without that block reports as uncorrectable, which is how an analysis says it has no fix. A cop that does correct still needs `extend RuboCop::Cop::AutoCorrector`.

An object holding several findings answers `each_offense` instead and yields one offense per finding, and the handler passes it to `report_each`.

A cop can investigate more than one file. Reset source-dependent state in `on_new_investigation`, and use the base class's `source_comments` reader rather than caching a source's comments on the cop.

## Shared helpers

Before writing a predicate or an extractor, read what is already in `lib/rubocop/callbacksystems/helpers`, since the reading you need is often there.

When two cops read the same thing, lift the primitive and leave each cop its policy. Finding the class a node sits in is a primitive and belongs there, while deciding what to do with that class is the cop's own business.

A module dropped in that directory wires itself. `Helpers` picks it up as it is defined, mixes it into every cop through the base class, and extends it with its siblings, so one helper calls another's predicates directly and no helper ever includes another. A class that wants them includes `RuboCop::Callbacksystems::Helpers`, never a submodule. A node that travels through several methods belongs in an object of its own instead.

## Adding a cop

Analysis that follows a value across methods or files has to be sound, and one file rarely shows where a value ends up. Prefer missing an offense over reporting code that works, since a rule that tells you to break working code is worse than one that misses cases.

A new cop needs its file, its paired test, and an entry in `config/default.yml` carrying its options and the paths it applies to.

## Tests

A cop test inherits `CopTestCase`, declares `self.cop_class`, and drives `assert_offense`, `assert_no_offense`, and `assert_correction` over heredoc sources. Cover the code the cop rejects and the code it leaves alone, and give every autocorrection its own case.

Analysis objects and helpers get their own tests, and `HelpersTestCase` parses source into the nodes a helper expects. There a test name begins with the method it covers, and the tests follow the order the source defines those methods, which the cops here enforce.

## Code style

- Rich objects over procedures, with small internal classes given their context in the constructor, private by default, and memoized getters instead of locals threaded through methods.
- One top-level class per file. Internal classes have no limit, so reach for one as soon as a piece of the reading deserves a name.
- Declarative naming, so code reads like prose. A value-returning method reads as the value (`limit`, not `compute_limit`), a query taking an argument carries a preposition (`children_of(node)`), and booleans read as predicates. The preposition is not forced on a lone argument whose call already reads on its own.
- Use full words while keeping established Ruby and Rails vocabulary such as `params`, `config` and `attr_reader`, as defined by [NoAbbreviations](lib/rubocop/cop/callbacksystems/no_abbreviations.rb).
- Keyword arguments when the call site would leave a reader guessing, as with two arguments of the same type or a bare boolean. One obvious argument stays positional.
- Comments are the exception. A cop's header and the sentence introducing an analysis object earn their place, while a comment narrating the next line does not, and a better name usually removes the need for it.

## The gem lints itself

`.rubocop.yml` inherits the shipped `rubocop.yml` and adds `rubocop-internal_affairs`, so the source has to pass the cops it ships. There is not a single inline disable in the repo, and a new exclusion in `.rubocop.yml` needs the reason written above it. Run the lint and read what actually fires before assuming what a cop will say.

## Quality bar

Code you touch leaves no duplication behind, reusing a helper or lifting one where two cops want the same predicate. It reads as prose, carries comments only where they earn their place, keeps its objects rich, and leaves `bin/test` and `bin/rubocop` green. Don't commit unless asked.
