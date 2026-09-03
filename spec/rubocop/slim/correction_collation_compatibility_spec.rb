# frozen_string_literal: true

require 'spec_helper'
require 'rubocop'

RSpec.describe RuboCop::Slim::CorrectionCollationCompatibility do
  describe '.install' do
    def legacy_team_class
      Class.new
    end

    it 'prepends the backport to legacy correction collation' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.75.2')

      expect(team_class.ancestors).to include(described_class::Backport)
    end

    it 'prepends the backport to the last release without buffer-aware collation' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.83.0')

      expect(team_class.ancestors).to include(described_class::Backport)
    end

    it 'leaves the first release with buffer-aware collation untouched' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.84.0')

      expect(team_class.ancestors).not_to include(described_class::Backport)
    end

    it 'leaves a buffer-aware release predating the extracted helper untouched' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.84.2')

      expect(team_class.ancestors).not_to include(described_class::Backport)
    end

    it 'leaves a buffer-aware release with the extracted helper untouched' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.88.2')

      expect(team_class.ancestors).not_to include(described_class::Backport)
    end

    it 'treats a prerelease of the first buffer-aware version as legacy' do
      team_class = legacy_team_class

      described_class.install(team_class, rubocop_version: '1.84.0.pre')

      expect(team_class.ancestors).to include(described_class::Backport)
    end

    it 'installs at most once' do
      team_class = legacy_team_class

      2.times { described_class.install(team_class, rubocop_version: '1.75.2') }

      expect(team_class.ancestors.count(described_class::Backport)).to eq(1)
    end

    it 'agrees with the running RuboCop on whether Team is patched' do
      legacy = Gem::Version.new(RuboCop::Version::STRING) < described_class::BUFFER_AWARE_VERSION

      expect(RuboCop::Cop::Team.ancestors.include?(described_class::Backport)).to eq(legacy)
    end
  end
end
