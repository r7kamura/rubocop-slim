# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Slim
    class Plugin < ::LintRoller::Plugin
      def about
        ::LintRoller::About.new(
          description: 'RuboCop plugin for Slim template.',
          homepage: 'https://github.com/r7kamura/rubocop-slim',
          name: 'rubocop-slim',
          version: VERSION
        )
      end

      def rules(_context)
        ::RuboCop::Runner.ruby_extractors.unshift(::RuboCop::Slim::RubyExtractor)

        ::LintRoller::Rules.new(
          config_format: :rubocop,
          type: :path,
          value: "#{__dir__}/../../../config/default.yml"
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end
    end
  end
end
