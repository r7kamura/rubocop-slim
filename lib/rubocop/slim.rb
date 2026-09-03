# frozen_string_literal: true

module RuboCop
  module Slim
    autoload :ConfigLoader, 'rubocop/slim/config_loader'
    autoload :CorrectionCollationCompatibility, 'rubocop/slim/correction_collation_compatibility'
    autoload :Directive, 'rubocop/slim/directive'
    autoload :DirectiveScanner, 'rubocop/slim/directive_scanner'
    autoload :DirectiveShadowBuilder, 'rubocop/slim/directive_shadow_builder'
    autoload :KeywordRemover, 'rubocop/slim/keyword_remover'
    autoload :ProcessedSourceBuilder, 'rubocop/slim/processed_source_builder'
    autoload :RubyClip, 'rubocop/slim/ruby_clip'
    autoload :RubyExtractor, 'rubocop/slim/ruby_extractor'
    autoload :WhenDecomposer, 'rubocop/slim/when_decomposer'
  end
end

require_relative 'slim/correction_collation_compatibility'
require_relative 'slim/plugin'
require_relative 'slim/version'

RuboCop::Slim::CorrectionCollationCompatibility.install
