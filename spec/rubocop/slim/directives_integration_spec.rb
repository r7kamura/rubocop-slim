# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, Sevencop/MethodDefinitionOrdered

require 'spec_helper'
require 'rubocop'
require 'rubocop/cli'
require 'rubocop/runner'
require 'stringio'
require 'tmpdir'

RSpec.describe 'RuboCop directives in Slim templates' do
  around do |example|
    extractors = RuboCop::Runner.ruby_extractors.dup
    example.run
  ensure
    RuboCop::Runner.ruby_extractors.replace(extractors)
  end

  def run_rubocop(
    source,
    *arguments,
    config: nil
  )
    config ||= <<~YAML
      AllCops:
        SuggestExtensions: false
      Style/StringLiterals:
        EnforcedStyle: single_quotes
    YAML

    Dir.mktmpdir do |directory|
      template = File.join(directory, 'template.slim')
      config_path = File.join(directory, '.rubocop.yml')
      File.write(template, source)
      File.write(config_path, config)

      unless RuboCop::Runner.ruby_extractors.include?(RuboCop::Slim::RubyExtractor)
        RuboCop::Runner.ruby_extractors.unshift(RuboCop::Slim::RubyExtractor)
      end

      original_stdout = $stdout
      original_stderr = $stderr
      output = StringIO.new
      error = StringIO.new
      $stdout = output
      $stderr = error
      result = RuboCop::CLI.new.run(['--config', config_path, *arguments, template])
      [result, output.string, error.string, File.read(template)]
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  def expect_generated_ruby_to_compile(source)
    ruby = Slimi::Engine.new.call(source)
    expect { RubyVM::InstructionSequence.compile(ruby) }.not_to raise_error
  end

  shared_examples 'a safe directive range' do |opening_directive, closing_directive|
    it 'suppresses and resumes inspection without breaking generated Ruby' do
      source = <<~SLIM
        p Préface
        #{opening_directive}
        p data-label=first = "ignored"
        #{closing_directive}
        = "reported"
      SLIM

      result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

      expect(result).to eq(1)
      expect(error).to be_empty
      expect(output).not_to include('ignored')
      expect(output).to include('template.slim:5:3: C: [Correctable] Style/StringLiterals')
      expect(output).to include('= "reported"')
      expect(output).to match(/^ {2}\^{10}$/)
      expect_generated_ruby_to_compile(source)
    end
  end

  it 'reports exact coordinates for every Ruby clip on a multi-clip line' do
    source = <<~SLIM
      p data-label=("tag") = "reported"
    SLIM

    result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

    expect(result).to eq(1)
    expect(error).to be_empty
    expect(output).to include('template.slim:1:15: C: [Correctable] Style/StringLiterals')
    expect(output).to include('template.slim:1:24: C: [Correctable] Style/StringLiterals')
    expect(output).to match(/^ {14}\^{5}$/)
    expect(output).to match(/^ {23}\^{10}$/)
    expect_generated_ruby_to_compile(source)
  end

  shared_examples 'an inert directive inside literal text' do |opener, marker|
    it "keeps reporting after #{marker} nested under #{opener.inspect}" do
      source = <<~SLIM
        #{opener}
          #{marker} rubocop:disable Style/StringLiterals
        = "reported"
      SLIM

      result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

      expect(result).to eq(1)
      expect(error).to be_empty
      expect(output).to include('template.slim:3:3: C: [Correctable] Style/StringLiterals')
      expect(output).to match(/^ {2}\^{10}$/)
      expect_generated_ruby_to_compile(source)
    end
  end

  include_examples 'an inert directive inside literal text', '| verbatim', '/'
  include_examples 'an inert directive inside literal text', '| verbatim', '- #'
  include_examples 'an inert directive inside literal text', "' verbatim", '/'
  include_examples 'an inert directive inside literal text', "' verbatim", '- #'
  include_examples 'an inert directive inside literal text', 'p literal', '/'
  include_examples 'an inert directive inside literal text', 'p literal', '- #'

  it 'still honors a directive nested under a container tag with no inline text' do
    source = <<~SLIM
      div
        / rubocop:disable Style/StringLiterals
        = "suppressed"
        / rubocop:enable Style/StringLiterals
      = "reported"
    SLIM

    result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

    expect(result).to eq(1)
    expect(error).to be_empty
    expect(output).not_to include('suppressed')
    expect(output).to include('template.slim:5:3: C: [Correctable] Style/StringLiterals')
    expect_generated_ruby_to_compile(source)
  end

  it 'registers the Slim extractor once across repeated runs in one example' do
    run_rubocop("= 'compliant'\n")
    run_rubocop("= 'compliant'\n")

    expect(RuboCop::Runner.ruby_extractors.count(RuboCop::Slim::RubyExtractor)).to eq(1)
  end

  context 'with Slim comment directives' do
    include_examples(
      'a safe directive range',
      '/ rubocop:disable Style/StringLiterals',
      '/ rubocop:enable Style/StringLiterals'
    )
  end

  context 'with standalone Ruby comment directives' do
    include_examples(
      'a safe directive range',
      '- # rubocop:disable Style/StringLiterals',
      '- # rubocop:enable Style/StringLiterals'
    )
  end

  shared_examples 'a non-redundant directive' do |directive|
    it 'does not create a redundant-disable offense or crash' do
      source = <<~SLIM
        #{directive}
        = "ignored"
      SLIM

      result, output, error, = run_rubocop(
        source,
        config: <<~YAML
          AllCops:
            SuggestExtensions: false
            DisabledByDefault: true
          Lint/RedundantCopDisableDirective:
            Enabled: true
          Style/StringLiterals:
            Enabled: true
            EnforcedStyle: single_quotes
        YAML
      )

      expect(error).to be_empty
      expect(output).not_to include('RedundantCopDisableDirective')
      expect(result).to eq(0)
      expect_generated_ruby_to_compile(source)
    end
  end

  context 'with non-redundant directives' do
    include_examples('a non-redundant directive', '/ rubocop:disable Style/StringLiterals')
    include_examples('a non-redundant directive', '- # rubocop:disable Style/StringLiterals')
  end

  shared_examples 'a redundant directive correction' do |directive|
    it 'autocorrects the complete standalone Slim construct safely' do
      source = <<~SLIM
        #{directive}
        = 'already compliant'
      SLIM

      result, output, error, corrected = run_rubocop(
        source,
        '--autocorrect',
        config: <<~YAML
          AllCops:
            SuggestExtensions: false
            DisabledByDefault: true
          Lint/RedundantCopDisableDirective:
            Enabled: true
          Lint/RedundantCopEnableDirective:
            Enabled: true
        YAML
      )

      expect(error).to be_empty
      expect(result).to eq(0)
      expect(output).to include('1 offense corrected')
      expect(corrected).to eq("= 'already compliant'\n")
      expect { Slimi::Parser.new(file: 'template.slim').call(corrected) }.not_to raise_error
      expect_generated_ruby_to_compile(corrected)
    end
  end

  context 'with redundant directives' do
    include_examples('a redundant directive correction', '/ rubocop:disable Style/StringLiterals')
    include_examples('a redundant directive correction', '- # rubocop:disable Style/StringLiterals')
  end

  it 'follows all, multiple-cop, repeated, and unmatched directive semantics' do
    source = <<~SLIM
      / rubocop:disable all
      = "first"
      / rubocop:enable all
      / rubocop:disable Style/StringLiterals, Layout/SpaceInsideStringInterpolation
      / rubocop:disable Style/StringLiterals
      = "second"
      / rubocop:enable Style/StringLiterals
      = "third"
      / rubocop:enable Style/StringLiterals
      = "fourth"
      / rubocop:disable Style/StringLiterals
      = "fifth"
    SLIM

    result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

    expect(result).to eq(1)
    expect(error).to be_empty
    expect(output).not_to include('first')
    expect(output).not_to include('second')
    expect(output).to include('template.slim:8:3: C: [Correctable] Style/StringLiterals')
    expect(output).to include('template.slim:10:3: C: [Correctable] Style/StringLiterals')
    expect(output).not_to include('fifth')
    expect_generated_ruby_to_compile(source)
  end

  it 'can enable a cop disabled by configuration' do
    source = <<~SLIM
      / rubocop:enable Style/StringLiterals
      = "reported"
    SLIM

    result, output, error, = run_rubocop(
      source,
      '--only',
      'Style/StringLiterals',
      config: <<~YAML
        AllCops:
          SuggestExtensions: false
        Style/StringLiterals:
          Enabled: false
          EnforcedStyle: single_quotes
      YAML
    )

    expect(result).to eq(1)
    expect(error).to be_empty
    expect(output).to include('template.slim:2:3: C: [Correctable] Style/StringLiterals')
    expect_generated_ruby_to_compile(source)
  end

  shared_examples 'a malformed directive diagnostic' do |directive|
    it 'reports an unknown cop at the original Slim directive location' do
      source = <<~SLIM
        p Préface
        #{directive}
        = "reported"
      SLIM

      result, output, error, = run_rubocop(
        source,
        config: <<~YAML
          AllCops:
            SuggestExtensions: false
            DisabledByDefault: true
          Lint/RedundantCopDisableDirective:
            Enabled: true
          Style/StringLiterals:
            Enabled: true
            EnforcedStyle: single_quotes
        YAML
      )

      expect(result).to eq(1)
      expect(error).to be_empty
      expect(output).to include('template.slim:2:')
      expect(output).to include('Style/UnknownCop')
      expect_generated_ruby_to_compile(source)
    end
  end

  context 'with malformed directives' do
    include_examples('a malformed directive diagnostic', '/ rubocop:disable Style/UnknownCop')
    include_examples('a malformed directive diagnostic', '- # rubocop:disable Style/UnknownCop')
  end

  it 'leaves directive-like text in unsupported contexts inactive' do
    source = <<~SLIM
      /! rubocop:disable Style/StringLiterals
      = "html"
      /[if IE]
        / rubocop:disable Style/StringLiterals
      = "conditional"
      javascript:
        / rubocop:disable Style/StringLiterals
      |
        / rubocop:disable Style/StringLiterals
      / comment
        / rubocop:disable Style/StringLiterals
      = "reported"
    SLIM

    result, output, error, = run_rubocop(source, '--only', 'Style/StringLiterals')

    expect(result).to eq(1)
    expect(error).to be_empty
    expect(output).to include('template.slim:2:3: C: [Correctable] Style/StringLiterals')
    expect(output).to include('template.slim:5:3: C: [Correctable] Style/StringLiterals')
    expect(output).to include('template.slim:12:3: C: [Correctable] Style/StringLiterals')
    expect_generated_ruby_to_compile(source)
  end
end

# rubocop:enable RSpec/DescribeClass, Sevencop/MethodDefinitionOrdered
