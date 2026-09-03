# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'spec_helper'
require 'rubocop'
require 'rubocop/cli'
require 'rubocop/runner'
require 'stringio'
require 'tmpdir'
require 'yaml'

RSpec.describe RuboCop::Slim::RubyExtractor do
  context 'with Ruby blocks' do
    around do |example|
      extractors = RuboCop::Runner.ruby_extractors.dup
      example.run
    ensure
      RuboCop::Runner.ruby_extractors.replace(extractors)
    end

    def run_rubocop(
      source,
      *arguments,
      config: '',
      plugin: false
    )
      Dir.mktmpdir do |directory|
        template = File.join(directory, 'template.slim')
        config_path = File.join(directory, '.rubocop.yml')
        File.write(template, source)
        plugins = <<~YAML if plugin
          plugins:
            - rubocop-slim
        YAML
        File.write(config_path, <<~YAML)
          #{plugins}AllCops:
            SuggestExtensions: false
          Style/StringLiterals:
            EnforcedStyle: single_quotes
          #{config}
        YAML

        RuboCop::Runner.ruby_extractors.unshift(RuboCop::Slim::RubyExtractor) unless plugin
        original_stdout = $stdout
        original_stderr = $stderr
        output = StringIO.new
        error = StringIO.new
        $stdout = output
        $stderr = error
        result = Dir.chdir(directory) do
          RuboCop::CLI.new.run(['--config', '.rubocop.yml', *arguments, 'template.slim'])
        end
        [result, output.string, error.string, File.read(template)]
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end

    it 'reports embedded Ruby diagnostics at their Slim locations' do
      source = <<~SLIM
        p Préface
        ruby:
          greeting = "Hello"
        p Between
        ruby:
          farewell = "Goodbye"
      SLIM

      result, output, error = run_rubocop(source, '--only', 'Style/StringLiterals')

      expect(result).to eq(1)
      expect(error).to be_empty
      expect(output).to include(
        'template.slim:3:14: C: [Correctable] Style/StringLiterals: Prefer single-quoted strings'
      )
      expect(output).to include('  greeting = "Hello"')
      expect(output).to include('             ^^^^^^^')
      expect(output).to include(
        'template.slim:6:14: C: [Correctable] Style/StringLiterals: Prefer single-quoted strings'
      )
      expect(output).to include('  farewell = "Goodbye"')
      expect(output).to include('             ^^^^^^^^^')
    end

    it 'honors native Ruby directives within an embedded Ruby block' do
      source = <<~SLIM
        ruby:
          # rubocop:disable Style/StringLiterals
          ignored = "Ignored"
          # rubocop:enable Style/StringLiterals
          reported = "Reported"
      SLIM

      result, output, = run_rubocop(source, '--only', 'Style/StringLiterals')

      expect(result).to eq(1)
      expect(output).not_to include('Ignored')
      expect(output).to include('template.slim:5:14: C: [Correctable] Style/StringLiterals')
    end

    it 'autocorrects only embedded string literals and preserves valid Slim indentation' do
      source = <<~SLIM
        p Before
        ruby:
          if enabled;
            greeting = "Hello";
          else;
            greeting = "Hi";
          end
        p After
      SLIM

      result, output, error, corrected = run_rubocop(
        source,
        '--only', 'Style/StringLiterals',
        '--autocorrect'
      )

      expect(result).to eq(0)
      expect(error).to be_empty
      expect(output).to include('2 offenses corrected')
      expect(corrected).to eq(<<~SLIM)
        p Before
        ruby:
          if enabled;
            greeting = 'Hello';
          else;
            greeting = 'Hi';
          end
        p After
      SLIM
      expect { Slimi::Parser.new(file: 'template.slim').call(corrected) }.not_to raise_error
      ruby = Slimi::Engine.new.call(corrected)
      expect { RubyVM::InstructionSequence.compile(ruby) }.not_to raise_error
    end

    it 'keeps InitialIndentation excluded in a consuming project' do
      source = <<~SLIM
        ruby:
          if enabled;
            greeting = "Hello";
          else;
            greeting = "Hi";
          end
      SLIM

      result, output, error, corrected = run_rubocop(
        source,
        '--only', 'Layout/InitialIndentation',
        '--autocorrect',
        plugin: true
      )

      expect(result).to eq(0)
      expect(output).to include('no offenses detected')
      expect(error).to be_empty
      expect(corrected).to eq(source)
    end

    it 'corrupts Slim indentation when InitialIndentation is overridden' do
      source = <<~SLIM
        ruby:
          if enabled;
            greeting = "Hello";
          else;
            greeting = "Hi";
          end
      SLIM

      result, output, error, corrected = run_rubocop(
        source,
        '--only', 'Layout/InitialIndentation',
        '--autocorrect',
        config: <<~YAML
          Layout/InitialIndentation:
            Exclude: []
        YAML
      )

      expect(result).to eq(0)
      expect(output).to include('1 offense corrected')
      expect(error).to be_empty
      expect(corrected).to start_with("ruby:\nif enabled;")
      processed_source = RuboCop::ProcessedSource.new(corrected, RUBY_VERSION.to_f, 'template.slim')
      sources = described_class.new(processed_source).call
      expect(sources.map { |fragment| fragment[:processed_source].raw_source }).not_to include(
        a_string_including('if enabled')
      )
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
