# rubocop-slim

[![test](https://github.com/r7kamura/rubocop-slim/actions/workflows/test.yml/badge.svg)](https://github.com/r7kamura/rubocop-slim/actions/workflows/test.yml)

[RuboCop](https://github.com/rubocop/rubocop) plugin for [Slim](https://github.com/slim-template/slim) template language.

## Installation

Install the gem and add to the application's Gemfile by executing:

```
bundle add rubocop-slim
```

If bundler is not being used to manage dependencies, install the gem by executing:

```
gem install rubocop-slim
```

## Usage

Require `"rubocop-slim"` in your RuboCop config.

```yaml
# .rubocop.yml
require:
  - rubocop-slim
```

Now you can use RuboCop also for Slim templates.

```
$ bundle exec rubocop spec/fixtures/dummy.slim
Inspecting 1 file
C

Offenses:

spec/fixtures/dummy.slim:1:3: C: [Correctable] Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.
- "a"
  ^^^
spec/fixtures/dummy.slim:3:5: C: [Correctable] Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.
| #{"c"}
    ^^^
spec/fixtures/dummy.slim:5:8: C: [Correctable] Style/ZeroLengthPredicate: Use !empty? instead of size > 0.
- a if array.size > 0
       ^^^^^^^^^^^^^^
spec/fixtures/dummy.slim:6:3: C: [Correctable] Style/NegatedIf: Favor unless over if for negative conditions.
- a if !b
  ^^^^^^^
spec/fixtures/dummy.slim:8:6: C: [Correctable] Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.
- if "a"
     ^^^

1 file inspected, 5 offenses detected, 5 offenses autocorrectable
```

## Related projects

- https://github.com/r7kamura/rubocop-erb
- https://github.com/r7kamura/rubocop-haml
- https://github.com/r7kamura/rubocop-markdown
