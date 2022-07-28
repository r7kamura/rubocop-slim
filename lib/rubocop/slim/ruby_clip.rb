# frozen_string_literal: true

module RuboCop
  module Slim
    RubyClip = ::Struct.new(
      :code,
      :offset,
      keyword_init: true
    )
  end
end
