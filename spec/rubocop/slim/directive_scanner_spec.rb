# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/slim/directive'
require 'rubocop/slim/directive_scanner'

RSpec.describe RuboCop::Slim::DirectiveScanner do
  describe '.call' do
    it 'finds standalone Slim and Ruby-comment directives with their positions' do
      source = "/ rubocop:disable Layout/LineLength\n- # rubocop:enable Layout/LineLength\n"

      expect(described_class.call(source)).to eq([
                                                   RuboCop::Slim::Directive.new(
                                                     line_start: 0, marker: '/', marker_offset: 0,
                                                     text: 'rubocop:disable Layout/LineLength'
                                                   ),
                                                   RuboCop::Slim::Directive.new(
                                                     line_start: 36, marker: '- #', marker_offset: 36,
                                                     text: 'rubocop:enable Layout/LineLength'
                                                   )
                                                 ])
    end

    it 'keeps character offsets with multibyte text, multiple directives, and a final Ruby comment' do
      source = <<~SLIM.chomp
        div title="café"
          / rubocop:disable Style/FrozenStringLiteralComment
          / rubocop:enable all
        - # rubocop:disable Metrics/MethodLength
      SLIM

      directives = described_class.call(source)

      expect(directives.map(&:marker_offset)).to eq([
                                                      source.index('/ rubocop:disable'),
                                                      source.index('/ rubocop:enable'),
                                                      source.index('- # rubocop:disable')
                                                    ])
      expect(directives.map(&:text)).to eq([
                                             'rubocop:disable Style/FrozenStringLiteralComment',
                                             'rubocop:enable all',
                                             'rubocop:disable Metrics/MethodLength'
                                           ])
    end

    it 'ignores directives nested under verbatim text that carries inline content' do
      source = <<~SLIM
        | verbatim
          / rubocop:disable Style/WordArray
        / rubocop:enable Style/WordArray
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:enable Style/WordArray'
                                                             ])
    end

    it 'ignores directives nested under apostrophe text that carries inline content' do
      source = <<~SLIM
        ' verbatim
          - # rubocop:disable Style/WordArray
        / rubocop:enable Style/WordArray
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:enable Style/WordArray'
                                                             ])
    end

    it 'ignores directives nested under a tag that carries inline text' do
      source = <<~SLIM
        p literal
          / rubocop:disable Style/WordArray
          - # rubocop:enable Style/WordArray
        / rubocop:disable Style/NumericLiterals
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/NumericLiterals'
                                                             ])
    end

    it 'keeps directives nested under a container tag with no inline text' do
      source = <<~SLIM
        div
          / rubocop:disable Style/WordArray
          - # rubocop:enable Style/WordArray
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/WordArray',
                                                               'rubocop:enable Style/WordArray'
                                                             ])
    end

    it 'does not find directive-shaped text in opaque Slim scopes' do
      source = <<~SLIM
        /! rubocop:disable All
        /[if IE]
          / rubocop:disable All
        / comment
          / rubocop:disable All
          p nested
        javascript:
          / rubocop:disable All
        css:
          - # rubocop:disable All
        markdown:
          / rubocop:disable All
        ruby:
          / rubocop:disable All
        |
          / rubocop:disable All
        '
          - # rubocop:disable All
        / rubocop:disable Style/WordArray
        - # rubocop:enable Style/WordArray
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/WordArray',
                                                               'rubocop:enable Style/WordArray'
                                                             ])
    end

    it 'keeps opaque comment bodies across blank lines' do
      source = <<~SLIM
        / comment

          / rubocop:disable All
        / rubocop:disable Style/WordArray
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/WordArray'
                                                             ])
    end

    it 'keeps a directive comment body opaque after recognizing its opener' do
      source = <<~SLIM
        / rubocop:disable Style/WordArray
          / rubocop:enable Style/WordArray
        = words.join(', ')
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/WordArray'
                                                             ])
    end

    it 'treats filter openers as opaque whether or not they carry inline content' do
      source = <<~SLIM
        coffee:
          / rubocop:disable All
        ruby: a = 1
          / rubocop:disable Style/WordArray
        / rubocop:disable Style/NumericLiterals
      SLIM

      expect(described_class.call(source).map(&:text)).to eq([
                                                               'rubocop:disable Style/NumericLiterals'
                                                             ])
    end
  end
end
