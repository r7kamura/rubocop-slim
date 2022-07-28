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
        expect(result[0].raw_source).to eq('b')
        expect(result[0].offset).to eq(4)
        expect(result[0].file_path).to eq(file_path)
        expect(result[1].raw_source).to eq('array.each')
        expect(result[1].offset).to eq(8)
        expect(result[2].raw_source).to eq('element')
        expect(result[2].offset).to eq(36)
      end
    end
  end
end
