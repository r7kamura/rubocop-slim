# frozen_string_literal: true

RSpec.describe RuboCop::Slim::RubyExtractor do
  describe '.call' do
    subject do
      described_class.call(processed_source)
    end

    let(:processed_source) do
      RuboCop::ProcessedSource.new(
        source,
        3.1,
        file_path
      )
    end

    let(:file_path) do
      'dummy.slim'
    end

    let(:source) do
      <<~SLIM
        a
        = b
        - array.each do |element|
          = element
      SLIM
    end

    context 'with valid condition' do
      it 'returns Ruby codes with offset' do
        result = subject
        expect(result.length).to eq(3)
        expect(result[0][:processed_source].raw_source).to eq('b')
        expect(result[0][:offset]).to eq(4)
        expect(result[0][:processed_source].file_path).to eq(file_path)
        expect(result[1][:processed_source].raw_source).to eq('array.each')
        expect(result[1][:offset]).to eq(8)
        expect(result[2][:processed_source].raw_source).to eq('element')
        expect(result[2][:offset]).to eq(36)
      end
    end

    context 'without standalone directives' do
      let(:source) do
        <<~SLIM
          - when primary, fallback
        SLIM
      end

      it 'retains compact transformed clips and their original offsets' do
        result = subject

        expect(result.map { |clip| clip[:processed_source].raw_source }).to eq(%w[primary fallback])
        expect(result.map { |clip| clip[:offset] }).to eq([7, 16])
      end
    end

    context 'with standalone Slim comment directives' do
      let(:source) do
        <<~SLIM
          / rubocop:disable Style/WordArray
          - records.each do |record|
        SLIM
      end

      it 'shadows transformed clips at their original positions' do
        result = subject
        shadow = result.fetch(0)

        expect(result.length).to eq(1)
        expect(shadow[:offset]).to eq(0)
        expect(shadow[:processed_source].raw_source.bytesize).to eq(source.bytesize)
        expect(shadow[:processed_source].raw_source).to start_with('# rubocop:disable Style/WordArray')
        expect(shadow[:processed_source].raw_source.byteslice(source.index('records.each'), 12)).to eq('records.each')
      end
    end

    context 'with multibyte text before standalone Slim comment directives' do
      let(:source) do
        <<~SLIM
          p café
          / rubocop:disable Style/WordArray
          = target
        SLIM
      end

      it 'keeps directive and Ruby clip positions in characters' do
        shadow = subject.fetch(0)[:processed_source].raw_source

        expect(shadow.index('# rubocop:disable Style/WordArray')).to eq(
          source.index('/ rubocop:disable Style/WordArray')
        )
        expect(shadow.index('target')).to eq(source.index('target'))
        expect(shadow.count("\n")).to eq(source.count("\n"))
      end
    end

    context 'with standalone Ruby comment directives' do
      let(:source) do
        <<~SLIM
          - # rubocop:disable Style/WordArray
          = items.map { |item| item.name } # native comment
        SLIM
      end

      it 'does not emit the directive clip and preserves native comments in the target shadow' do
        result = subject
        shadow = result.fetch(0)

        expect(result.length).to eq(1)
        expect(shadow[:offset]).to eq(0)
        expect(shadow[:processed_source].raw_source).to start_with('#   rubocop:disable Style/WordArray')
        expect(shadow[:processed_source].raw_source).to include('items.map { |item| item.name } # native comment')
      end
    end

    context 'with multiple directives and Ruby clips' do
      let(:source) do
        <<~SLIM
          / rubocop:disable Style/WordArray
          = first
          - # rubocop:disable Metrics/MethodLength
          = second
        SLIM
      end

      it 'applies directives according to marker position before each final clip' do
        result = subject
        first_shadow, second_shadow = result

        expect(first_shadow[:offset]).to eq(0)
        expect(first_shadow[:processed_source].raw_source).to include('# rubocop:disable Style/WordArray')
        expect(first_shadow[:processed_source].raw_source).not_to include('Metrics/MethodLength')
        expect(first_shadow[:processed_source].raw_source.byteslice(source.index('first'), 5)).to eq('first')
        expect(second_shadow[:offset]).to eq(0)
        expect(second_shadow[:processed_source].raw_source).to include('# rubocop:disable Style/WordArray')
        expect(second_shadow[:processed_source].raw_source).to include('#   rubocop:disable Metrics/MethodLength')
        expect(second_shadow[:processed_source].raw_source.byteslice(source.index('second'), 6)).to eq('second')
      end
    end

    context 'with multiple Ruby clips on one line' do
      let(:source) do
        <<~SLIM
          / rubocop:disable Style/WordArray
          a href=first = second
        SLIM
      end

      it 'creates a distinct shadow for each clip' do
        result = subject

        expect(result.map { |clip| clip[:offset] }).to eq([0, 0])
        expect(result.map { |clip| clip[:processed_source].raw_source.byteslice(source.index('first'), 5) }).to eq(
          ['first', '     ']
        )
        expect(result.map { |clip| clip[:processed_source].raw_source.byteslice(source.index('second'), 6) }).to eq(
          ['      ', 'second']
        )
      end
    end

    context 'with trailing code comments after do block' do
      let(:source) do
        <<~SLIM
          - array.each do |element| # code comment
            = element
        SLIM
      end

      it 'returns Ruby codes with offset' do
        result = subject
        expect(result.length).to eq(2)
        expect(result[0][:processed_source].raw_source).to eq('array.each')
        expect(result[0][:offset]).to eq(2)
        expect(result[1][:processed_source].raw_source).to eq('element')
        expect(result[1][:offset]).to eq(45)
      end
    end

    context 'with `foo(bar)do`' do
      let(:source) do
        <<~SLIM
          - foo(bar)do
        SLIM
      end

      it 'returns `foo(bar)` part' do
        result = subject
        expect(result.length).to eq(1)
        expect(result[0][:processed_source].raw_source).to eq('foo(bar)')
      end
    end

    context 'with `when a, b`' do
      let(:source) do
        <<~SLIM
          - when a, b
        SLIM
      end

      it 'returns Ruby codes for a and b' do
        result = subject
        expect(result.length).to eq(2)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(7)
        expect(result[1][:processed_source].raw_source).to eq('b')
        expect(result[1][:offset]).to eq(10)
      end
    end

    context 'with `else`' do
      let(:source) do
        <<~SLIM
          - if a
            p b
          - else
            p c
        SLIM
      end

      it 'returns Ruby codes for a and b' do
        result = subject
        expect(result.length).to eq(2)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(5)
        expect(result[1][:processed_source].raw_source).to eq('')
        expect(result[1][:offset]).to eq(19)
      end
    end

    context 'with `when`' do
      let(:source) do
        <<~SLIM
          - when a
        SLIM
      end

      it 'returns Ruby codes for when condition' do
        result = subject
        expect(result.length).to eq(1)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(7)
      end
    end

    context 'with `when ... then`' do
      let(:source) do
        <<~SLIM
          - when a then
        SLIM
      end

      it 'returns Ruby codes for when condition' do
        result = subject
        expect(result.length).to eq(1)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(7)
      end
    end

    context 'with `when ... then ...`' do
      let(:source) do
        <<~SLIM
          - when a then b
        SLIM
      end

      it 'returns Ruby codes for when condition' do
        result = subject
        expect(result.length).to eq(1)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(7)
      end
    end

    context 'with `when ... # ...`' do
      let(:source) do
        <<~SLIM
          - when a # b
        SLIM
      end

      it 'returns Ruby codes for when condition' do
        result = subject
        expect(result.length).to eq(1)
        expect(result[0][:processed_source].raw_source).to eq('a')
        expect(result[0][:offset]).to eq(7)
      end
    end
  end
end
