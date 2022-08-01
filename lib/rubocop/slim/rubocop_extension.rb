# frozen_string_literal: true

require 'rubocop'

RuboCop::Runner.ruby_extractors.unshift(RuboCop::Slim::RubyExtractor)

RuboCop::ConfigLoader.instance_variable_set(
  :@default_configuration,
  RuboCop::Slim::ConfigLoader.call
)
