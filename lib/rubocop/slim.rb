# frozen_string_literal: true

module RuboCop
  module Slim
    autoload :ConfigLoader, 'rubocop/slim/config_loader'
    autoload :RubyClip, 'rubocop/slim/ruby_clip'
    autoload :RubyClipper, 'rubocop/slim/ruby_clipper'
    autoload :RubyExtractor, 'rubocop/slim/ruby_extractor'
  end
end

require_relative 'slim/rubocop_extension'
require_relative 'slim/version'
