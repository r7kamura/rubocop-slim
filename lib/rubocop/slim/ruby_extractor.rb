# frozen_string_literal: true

require 'rubocop'
require 'slimi'

module RuboCop
  module Slim
    # Extract Ruby codes from Slim template.
    class RubyExtractor
      class << self
        # @param [RuboCop::ProcessedSource] processed_source
        # @return [Array<RuboCop::ProcessedSource>, nil]
        def call(processed_source)
          new(processed_source).call
        end
      end

      # @param [RuboCop::ProcessedSource] processed_source
      def initialize(processed_source)
        @processed_source = processed_source
      end

      # @return [Array<RuboCop::ProcessedSource>, nil]
      def call
        return unless supported_file_path_pattern?

        directives = DirectiveScanner.call(template_source)

        ruby_clips(directives).map do |ruby_clip|
          {
            offset: ruby_clip.offset,
            processed_source: ProcessedSourceBuilder.call(
              code: ruby_clip.code,
              processed_source: @processed_source
            )
          }
        end
      end

      private

      # @return [Array] Slim AST, represented in S-expression.
      def ast
        ::Slimi::Filters::Interpolation.new.call(
          ::Slimi::Parser.new(file: file_path).call(template_source)
        )
      end

      # @return [String, nil]
      def file_path
        @processed_source.path
      end

      # @return [Array<RuboCop::Slim::RubyClip]
      def ruby_clips(directives)
        clips = ruby_ranges.map do |(begin_, end_)|
          RubyClip.new(
            code: template_source[begin_...end_],
            offset: begin_
          )
        end.flat_map do |ruby_clip|
          WhenDecomposer.call(@processed_source, ruby_clip)
        end.map do |ruby_clip|
          KeywordRemover.call(ruby_clip)
        end.reject do |ruby_clip|
          standalone_ruby_comment_directive?(ruby_clip, directives)
        end

        return clips if directives.empty?

        clips.map do |ruby_clip|
          DirectiveShadowBuilder.call(
            directives: directives,
            ruby_clip: ruby_clip,
            source: template_source
          )
        end
      end

      def ruby_comment_directive_clip?(
        ruby_clip,
        directive
      )
        return false unless directive.marker == '- #'

        line_end = template_source.index("\n", directive.line_start) || template_source.length
        clip_range = ruby_clip.offset...(ruby_clip.offset + ruby_clip.code.length)
        marker_range = directive.marker_offset...line_end

        clip_range.begin >= marker_range.begin && clip_range.end <= marker_range.end &&
          ruby_clip.code.match?(/\A#\s*#{Regexp.escape(directive.text)}\z/)
      end

      # @return [Array<Array<Integer>>]
      def ruby_ranges
        result = []
        traverse(ast) do |begin_, end_|
          result << [begin_, end_]
        end
        result
      end

      def standalone_ruby_comment_directive?(
        ruby_clip,
        directives
      )
        directives.any? do |directive|
          ruby_comment_directive_clip?(ruby_clip, directive)
        end
      end

      # @return [Boolean]
      def supported_file_path_pattern?
        file_path&.end_with?('.slim')
      end

      # @return [String]
      def template_source
        @processed_source.raw_source
      end

      def traverse(
        node,
        &block
      )
        return unless node.instance_of?(::Array)

        block.call(node[2], node[3]) if node[0] == :slimi && node[1] == :position
        node.each do |element|
          traverse(element, &block)
        end
      end
    end
  end
end
