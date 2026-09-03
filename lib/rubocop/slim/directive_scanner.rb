# frozen_string_literal: true

require 'slimi'

module RuboCop
  module Slim
    # Locates standalone RuboCop directives without interpreting opaque Slim bodies.
    class DirectiveScanner
      class << self
        # @param [String] source
        # @return [Array<RuboCop::Slim::Directive>]
        def call(source)
          new(source).call
        end
      end

      def initialize(source)
        @source = source
      end

      def call
        directives = []
        opaque_indents = []
        line_offset = 0

        @source.each_line do |line|
          unless line.strip.empty?
            indentation = line[/\A[ \t]*/]
            indent_size = indentation.length
            opaque_indents.pop while opaque_indents.last && indent_size <= opaque_indents.last

            unless opaque_indents.any?
              directive = directive_on(line, line_offset, indentation)
              directives << directive if directive && !literal_text?(directive.marker_offset)
              opaque_indents << indent_size if starts_opaque_scope?(line, indentation)
            end
          end

          line_offset += line.length
        end

        directives
      end

      private

      def directive_on(
        line,
        line_offset,
        indentation
      )
        content = line[indentation.length..].to_s.sub(/\r?\n\z/, '')
        marker_offset = line_offset + indentation.length

        if (match = content.match(%r{\A/[ \t]+(rubocop:.*)\z}))
          Directive.new(
            line_start: line_offset,
            marker: '/',
            marker_offset: marker_offset,
            text: match[1]
          )
        elsif (match = content.match(/\A- \#[ \t]*(rubocop:.*)\z/))
          Directive.new(
            line_start: line_offset,
            marker: '- #',
            marker_offset: marker_offset,
            text: match[1]
          )
        end
      end

      def interpolate_ranges(
        node,
        ranges
      )
        return ranges unless node.is_a?(::Array)

        ranges << [node[2], node[3]] if node[0] == :slimi && node[1] == :interpolate
        node.each { |child| interpolate_ranges(child, ranges) }
        ranges
      end

      # Slim hands every line indented under a text opener to the parser's
      # text-block rule, which swallows it verbatim however it is written, so a
      # directive landing there is decoration rather than instruction. The
      # openers are not separable lexically: a tag's inline text is only
      # distinguishable from its children once attributes have been parsed, and
      # an attribute value may itself contain spaces, quotes, and Ruby. Ask the
      # parser where the text went instead of trying to recognize its openers.
      def literal_text?(offset)
        literal_text_ranges.any? { |(begin_, end_)| offset >= begin_ && offset < end_ }
      end

      def literal_text_ranges
        @literal_text_ranges ||= interpolate_ranges(parsed_ast, [])
      end

      # An unparsable template is reported as a syntax error by the extractor;
      # directive scanning degrades to the lexical openers rather than raising
      # first and replacing that diagnostic with a crash.
      def parsed_ast
        ::Slimi::Parser.new(file: '(source)').call(@source)
      rescue ::Slimi::Errors::SlimSyntaxError
        []
      end

      # Recognizes only the openers whose bodies leave no trace in the AST, plus
      # the bare text markers relied on when the template cannot be parsed.
      # Everything else defers to #literal_text?.
      def starts_opaque_scope?(
        line,
        indentation
      )
        content = line[indentation.length..].to_s.sub(/\r?\n\z/, '')
        return true if content.start_with?('/')
        return true if ['|', "'"].include?(content)

        content.match?(/\A\p{Word}+:\z/)
      end
    end
  end
end
