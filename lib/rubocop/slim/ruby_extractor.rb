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

        ruby_clips.map do |ruby_clip|
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
      def ruby_clips
        ruby_ranges.map do |(begin_, end_)|
          RubyClip.new(
            code: template_source[begin_...end_],
            offset: begin_
          )
        end.flat_map do |ruby_clip|
          WhenDecomposer.call(@processed_source, ruby_clip)
        end.map do |ruby_clip|
          KeywordRemover.call(ruby_clip)
        end
      end

      # @return [Array<Array<Integer>>]
      def ruby_ranges
        result = []
        traverse(ast) do |begin_, end_|
          result << [begin_, end_]
        end
        result
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
