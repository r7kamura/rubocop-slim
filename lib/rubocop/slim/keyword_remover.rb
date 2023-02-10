# frozen_string_literal: true

module RuboCop
  module Slim
    # Remove unnecessary part (e.g. `if`, `unless`, `do`, ...) from Ruby-ish code.
    class KeywordRemover
      class << self
        # @param [RuboCop::Slim::RubyClip] ruby_clip
        # @return [RuboCop::Slim::RubyClip]
        def call(ruby_clip)
          new(ruby_clip).call
        end
      end

      # @param [String] ruby_clip
      def initialize(ruby_clip)
        @ruby_clip = ruby_clip
      end

      # @return [RuboCop::Slim::RubyClip]
      def call
        [
          PrecedingKeywordRemover,
          TrailingDoRemover
        ].reduce(@ruby_clip) do |previous, callable|
          result = callable.call(previous.code)
          RubyClip.new(
            code: result.code,
            offset: previous.offset + result.offset
          )
        end
      end

      # Remove preceding keyword.
      class PrecedingKeywordRemover
        REGEXP = /
          \A
          (?:
            begin
            | case
            | else
            | elsif
            | ensure
            | if
            | rescue
            | unless
            | until
            | when
            | while
            | for[ \t]+\w+[ \t]+in
          )
          [ \t]
        /x.freeze

        class << self
          # @param [String] code
          # @return [RubyClip]
          def call(code)
            new(code).call
          end
        end

        # @param [String] code
        def initialize(code)
          @code = code
        end

        # @return [Hash]
        def call
          data = @code.match(REGEXP)
          if data
            offset = data[0].length
            RubyClip.new(
              code: @code[offset..],
              offset: offset
            )
          else
            RubyClip.new(
              code: @code,
              offset: 0
            )
          end
        end
      end

      # Remove trailing `do`.
      class TrailingDoRemover
        REGEXP = /
          [ \t]
          do
          [ \t]*
          (\|[^|]*\|)?
          [ \t]*
          \Z
        /x.freeze

        class << self
          # @param [String] code
          # @return [RubyClip]
          def call(code)
            new(code).call
          end
        end

        # @param [String] code
        def initialize(code)
          @code = code
        end

        # @return [Hash]
        def call
          RubyClip.new(
            code: @code.sub(REGEXP, ''),
            offset: 0
          )
        end
      end
    end
  end
end
