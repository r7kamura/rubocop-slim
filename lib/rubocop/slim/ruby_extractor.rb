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
        @ast ||= ::Slimi::Filters::Interpolation.new.call(raw_ast)
      end

      # @return [Array<RuboCop::Slim::RubyClip>]
      def embedded_ruby_clips
        embedded_ruby_ranges.filter_map do |begin_, end_|
          code = template_source[begin_...end_]
          next if code.strip.empty?

          RubyClip.new(code: code, offset: begin_)
        end
      end

      # @return [Array]
      def embedded_ruby_nodes
        nodes = []
        traverse_raw_ast(raw_ast) do |node|
          nodes << node if node[0..1] == %i[slimi embedded] && node[2] == 'ruby'
        end
        nodes
      end

      # @param [Array] body
      # @return [Array<Integer>, nil]
      def embedded_ruby_range(body)
        positions = interpolation_positions(body)
        return if positions.empty?

        begin_ = positions.map(&:first).min
        end_ = positions.map(&:last).max
        [physical_line_beginning(begin_), end_]
      end

      # @return [Array<Array<Integer>>]
      def embedded_ruby_ranges
        embedded_ruby_nodes.filter_map do |node|
          embedded_ruby_range(node[3])
        end
      end

      # @return [String, nil]
      def file_path
        @processed_source.path
      end

      # @param [Array] node
      # @return [Array<Array<Integer>>]
      def interpolation_positions(node)
        return [] unless node.instance_of?(::Array)

        position = [node[2], node[3]] if node[0..1] == %i[slimi interpolate]
        node.flat_map { |element| interpolation_positions(element) } + [position].compact
      end

      # @return [Array<RuboCop::Slim::RubyClip>]
      def ordinary_ruby_clips
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

      # @param [Integer] offset
      # @return [Integer]
      def physical_line_beginning(offset)
        return 0 if offset.zero?

        template_source.rindex("\n", offset - 1)&.+(1) || 0
      end

      # @return [Array] Slim AST before interpolation is applied.
      def raw_ast
        @raw_ast ||= ::Slimi::Parser.new(file: file_path).call(template_source)
      end

      # @return [Array<RuboCop::Slim::RubyClip]
      def ruby_clips
        (ordinary_ruby_clips + embedded_ruby_clips).sort_by(&:offset)
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

        return if node[0..1] == %i[slimi embedded] && node[2] == 'ruby'

        block.call(node[2], node[3]) if node[0] == :slimi && node[1] == :position
        node.each do |element|
          traverse(element, &block)
        end
      end

      def traverse_raw_ast(
        node,
        &block
      )
        return unless node.instance_of?(::Array)

        block.call(node)
        node.each { |element| traverse_raw_ast(element, &block) }
      end
    end
  end
end
