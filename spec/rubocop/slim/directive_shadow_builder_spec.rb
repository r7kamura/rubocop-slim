# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/slim/directive'
require 'rubocop/slim/ruby_clip'
require 'rubocop/slim/directive_shadow_builder'

RSpec.describe RuboCop::Slim::DirectiveShadowBuilder do
  describe '.call' do
    it 'returns a character-position-preserving Ruby shadow for a Slim comment directive' do
      source = "p café\n/ rubocop:disable Style/WordArray\n= target\n"
      directive = directive_at(source, '/ rubocop:disable', '/')
      ruby_clip = RuboCop::Slim::RubyClip.new(
        code: 'target', offset: source.index('target')
      )

      shadow = described_class.call(
        directives: [directive], ruby_clip: ruby_clip, source: source
      )

      expect(shadow.offset).to eq(0)
      expect(shadow.code.length).to eq(source.length)
      expect(shadow.code.encoding).to eq(source.encoding)
      expect(shadow.code.count("\n")).to eq(source.count("\n"))
      expect(shadow.code).to start_with("      \n# rubocop:disable Style/WordArray\n")
      expect(shadow.code[ruby_clip.offset, ruby_clip.code.length]).to eq('target')
    end

    it 'preserves CRLF newlines while normalizing directives' do
      source = "/ rubocop:disable Style/WordArray\r\n= value\r\n"
      directive = directive_at(source, '/ rubocop:disable', '/')
      ruby_clip = RuboCop::Slim::RubyClip.new(
        code: 'value', offset: source.index('value')
      )

      shadow = described_class.call(
        directives: [directive], ruby_clip: ruby_clip, source: source
      )

      expect(shadow.code).to start_with("# rubocop:disable Style/WordArray\r\n")
      expect(shadow.code.bytes.select { |byte| [10, 13].include?(byte) }).to eq(
        source.bytes.select { |byte| [10, 13].include?(byte) }
      )
    end

    it 'normalizes a Ruby-comment directive from its Slim marker without leaving a bare dash' do
      source = "- # rubocop:disable Layout/LineLength\n= value\n"
      directive = directive_at(source, '- # rubocop:disable', '- #')
      ruby_clip = RuboCop::Slim::RubyClip.new(
        code: 'value', offset: source.index('value')
      )

      shadow = described_class.call(
        directives: [directive], ruby_clip: ruby_clip, source: source
      )

      expect(shadow.code).to start_with("#   rubocop:disable Layout/LineLength\n")
      expect(shadow.code).not_to include('- #')
    end

    it 'includes multiple preceding directives and only the transformed Ruby clip' do
      source = <<~SLIM
        / rubocop:disable Metrics/MethodLength
        - # rubocop:disable Style/WordArray
        - records.each do |record|
          = record.name
      SLIM
      directives = [
        directive_at(source, '/ rubocop:disable', '/'),
        directive_at(source, '- # rubocop:disable', '- #')
      ]
      ruby_clip = RuboCop::Slim::RubyClip.new(
        code: 'records.each', offset: source.index('records.each')
      )

      shadow = described_class.call(
        directives: directives, ruby_clip: ruby_clip, source: source
      )

      expect(shadow.code).to include('# rubocop:disable Metrics/MethodLength')
      expect(shadow.code).to include('#   rubocop:disable Style/WordArray')
      expect(shadow.code[ruby_clip.offset, ruby_clip.code.length]).to eq('records.each')
      expect(shadow.code).not_to include('record.name')
    end

    it 'uses the selected clip when multiple Ruby clips share one line' do
      source = "/ rubocop:disable Style/WordArray\n= first = second\n"
      directive = directive_at(source, '/ rubocop:disable', '/')
      ruby_clip = RuboCop::Slim::RubyClip.new(
        code: 'second', offset: source.index('second')
      )

      shadow = described_class.call(
        directives: [directive], ruby_clip: ruby_clip, source: source
      )

      expect(shadow.code[source.index('first'), 5]).to eq('     ')
      expect(shadow.code[ruby_clip.offset, 6]).to eq('second')
    end

    def directive_at(
      source,
      marker_start,
      marker
    )
      marker_offset = source.index(marker_start)
      RuboCop::Slim::Directive.new(
        line_start: source.rindex("\n", marker_offset - 1).to_i + 1,
        marker: marker,
        marker_offset: marker_offset,
        text: directive_text(source, marker_offset, marker)
      )
    end

    def directive_text(
      source,
      marker_offset,
      marker
    )
      source[marker_offset + marker.length..]
        .split(/\r?\n/, 2)
        .first
        .sub(/\A\s*#?\s*/, '')
    end
  end
end
