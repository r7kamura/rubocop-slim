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
