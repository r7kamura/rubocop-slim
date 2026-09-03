# frozen_string_literal: true

module RuboCop
  module Slim
    RubyClip = Class.new(
      if defined?(::Data) && ::Data.respond_to?(:define)
        ::Data.define(:code, :offset)
      else
        ::Struct.new(
          :code,
          :offset,
          keyword_init: true
        )
      end
    )
  end
end
