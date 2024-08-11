# frozen_string_literal: true

module RuboCop
  module Slim
    autoload :ConfigLoader, 'rubocop/slim/config_loader'
    autoload :KeywordRemover, 'rubocop/slim/keyword_remover'
    autoload :ProcessedSourceBuilder, 'rubocop/slim/processed_source_builder'
    autoload :RubyClip, 'rubocop/slim/ruby_clip'
    autoload :RubyExtractor, 'rubocop/slim/ruby_extractor'
    autoload :WhenDecomposer, 'rubocop/slim/when_decomposer'
  end
end

require_relative 'slim/rubocop_extension'
require_relative 'slim/version'
