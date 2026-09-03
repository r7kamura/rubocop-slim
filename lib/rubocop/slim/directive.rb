# frozen_string_literal: true

module RuboCop
  module Slim
    Directive = Class.new(
      if defined?(::Data) && ::Data.respond_to?(:define)
        ::Data.define(:marker_offset, :line_start, :marker, :text)
      else
        ::Struct.new(
          :marker_offset,
          :line_start,
          :marker,
          :text,
          keyword_init: true
        )
      end
    )
  end
end
