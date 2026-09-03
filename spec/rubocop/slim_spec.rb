# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RuboCop::Slim do
  it 'uses immutable Data classes for value objects when available' do
    skip 'Data is unavailable before Ruby 3.2' unless defined?(Data)

    expect(RuboCop::Slim::Directive).to be < Data
    expect(RuboCop::Slim::RubyClip).to be < Data
  end
end
