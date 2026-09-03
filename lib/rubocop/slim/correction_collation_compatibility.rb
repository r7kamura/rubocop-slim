# frozen_string_literal: true

require 'rubocop/cop/team'
require 'rubocop/version'

module RuboCop
  module Slim
    # Backports RuboCop's source-buffer-aware correction collation for extractors.
    module CorrectionCollationCompatibility
      # RuboCop 1.84.0 taught correction collation to import correctors from
      # foreign buffers, even at offset 0. Position-preserving directive shadows
      # need that behavior to correct Slim. 1.86.0 later extracted the same
      # branch into a private +merge_corrector!+ helper, so the helper's presence
      # marks 1.86, not the behavior; only the version boundary does.
      BUFFER_AWARE_VERSION = Gem::Version.new('1.84')

      module Backport
        private

        def collate_corrections(
          report,
          offset:,
          original:
        )
          corrector = RuboCop::Cop::Corrector.new(original)

          each_corrector(report) do |to_merge|
            suppress_clobbering do
              if corrector.source_buffer == to_merge.source_buffer
                corrector.merge!(to_merge)
              else
                corrector.import!(to_merge, offset: offset)
              end
            end
          end

          corrector
        end
      end

      def self.install(
        team_class = RuboCop::Cop::Team,
        rubocop_version: RuboCop::Version::STRING
      )
        return if Gem::Version.new(rubocop_version) >= BUFFER_AWARE_VERSION
        return if team_class.ancestors.include?(Backport)

        team_class.prepend(Backport)
      end
    end
  end
end
