# frozen_string_literal: true

module RuboCop
  module Slim
    # Builds an absolute-position Ruby source containing directives and one clip.
    class DirectiveShadowBuilder
      class << self
        # @param [String] source
        # @param [RuboCop::Slim::RubyClip] ruby_clip
        # @param [Array<RuboCop::Slim::Directive>] directives
        # @return [RuboCop::Slim::RubyClip]
        def call(
          directives:,
          ruby_clip:,
          source:
        )
          new(source, ruby_clip, directives).call
        end
      end

      def initialize(
        source,
        ruby_clip,
        directives
      )
        @source = source
        @ruby_clip = ruby_clip
        @directives = directives
      end

      def call
        shadow = blank_source
        preceding_directives.each { |directive| write_directive(shadow, directive) }
        write(shadow, @ruby_clip.offset, @ruby_clip.code)

        RubyClip.new(code: shadow, offset: 0)
      end

      private

      def blank_source
        @source.gsub(/[^\r\n]/, ' ')
      end

      def line_end_after(offset)
        @source.index(/[\r\n]/, offset) || @source.length
      end

      def preceding_directives
        @directives.select { |directive| directive.marker_offset < @ruby_clip.offset }
      end

      def write(
        shadow,
        offset,
        text
      )
        shadow[offset, text.length] = text
      end

      def write_directive(
        shadow,
        directive
      )
        line_end = line_end_after(directive.marker_offset)
        length = line_end - directive.marker_offset
        padding = length - directive.text.length - 1

        write(
          shadow,
          directive.marker_offset,
          "##{' ' * padding}#{directive.text}"
        )
      end
    end
  end
end
