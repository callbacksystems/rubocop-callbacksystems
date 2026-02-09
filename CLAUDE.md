# RuboCop Callbacksystems

Custom RuboCop cops implementing the Callbacksystems Ruby style guide.

## Critical Rule

**NEVER disable or adjust RuboCop rules to create exceptions.** The purpose of this gem is to enforce good programming practices. If a cop flags code, fix the code—don't weaken the rule.

## What

Custom cops covering:
- Naming conventions (no abbreviations, plural controllers, etc.)
- Method patterns (early returns, no bang methods without counterpart)
- Testing (single-line setup, no assert_select, fixture helpers)
- Architecture (no service objects, private nested classes)

Uses Zeitwerk for autoloading.

## Commands

```bash
bin/rubocop    # Run RuboCop with custom cops
bin/test       # Run all tests
```
