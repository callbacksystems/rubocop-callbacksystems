# RuboCop Callbacksystems

Custom RuboCop cops implementing the Callbacksystems Ruby style guide.

## Critical Rule

**NEVER disable or adjust RuboCop rules to create exceptions.** The purpose of this gem is to enforce good programming practices. If a cop flags code, fix the code instead of weakening the rule.

## What

Custom cops covering:
- Naming conventions (no abbreviations, plural controllers, etc.)
- Method patterns (early returns, no bang methods without counterpart)
- Testing (single-line setup, no assert_select, fixture helpers)
- Architecture (no service objects, private nested classes)

Uses Zeitwerk for autoloading.

## Writing a cop

- The `on_*` handler finds the offense and hands the correction to the object that found it, rather than doing range arithmetic itself. That object appears when the analysis needs state of its own, and then it owns the message too, because it owns the data the message names. A cop small enough to be a few private methods needs no object.
- Shared predicates belong in `lib/rubocop/callbacksystems/helpers`. A node that travels through several methods belongs in an object instead, which is what `NodeVisibility` and `BodySections` are for.
- A definition with no body says what something is and no placement rule reaches it. Only a definition carrying behavior, a class with methods or a builder given a block, answers to where things go.
- Analysis that follows a value across methods or files has to be sound. An instance also travels as an argument, as an element of a collection and as a return value, and no reading of one file follows it there, so prefer missing an offense over reporting code that works. A rule that tells you to break working code is worse than one that misses cases.
- When a core cop cannot express the rule, write ours and leave the core one off for a stated reason. Its options are not there to be loosened.
- An autocorrect answers to `test/fixer_safety_test.rb` as well as its own suite. Every correcting cop is run over the heredocs in its tests with a comment inserted before each line in turn, and must not drop the comment or leave the source unparseable. Where the new shape has room for the comment, carry it; where a one-line form has none, report the offense and skip the correction. A cop whose tests build sources some other way needs an entry in `EXTRA_PROBES`, not an exemption.

## Commands

```bash
bin/rubocop    # Run RuboCop with custom cops
bin/test       # Run all tests
```
