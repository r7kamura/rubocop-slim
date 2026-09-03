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

    context 'with embedded Ruby filters' do
      let(:file_path) do
        'example.slim'
      end

      it 'returns a complete multiline body from its first physical line' do
        source = <<~SLIM
          p Before
          ruby:
            if enabled
              greeting = "Hello \#{name}"
            else
              greeting = "Hi"
            end
        SLIM
        result = described_class.call(
          RuboCop::ProcessedSource.new(source, 3.1, file_path)
        )

        expect(result.length).to eq(1)
        expected_body = <<~RUBY.gsub(/^/, '  ').chomp
          if enabled
            greeting = "Hello \#{name}"
          else
            greeting = "Hi"
          end
        RUBY
        expect(result.first[:processed_source].raw_source).to eq(expected_body)
        expect(result.first[:offset]).to eq(source.index('  if enabled'))
        expect(result.first[:processed_source].file_path).to eq('example.slim')
        expect(result.first[:processed_source].raw_source.scan("\#{name}")).to eq(["\#{name}"])
      end

      it 'preserves complete case control flow' do
        source = <<~SLIM
          ruby:
            case status
            when :active
              :enabled
            else
              :disabled
            end
        SLIM
        result = described_class.call(
          RuboCop::ProcessedSource.new(source, 3.1, file_path)
        )

        expected_body = <<~RUBY.gsub(/^/, '  ').chomp
          case status
          when :active
            :enabled
          else
            :disabled
          end
        RUBY
        expect(result.map { |clip| clip[:processed_source].raw_source }).to eq([expected_body])
      end

      it 'keeps multiple bodies in source order' do
        source = <<~SLIM
          p Before
          ruby:
            first = 1
          p Between
          ruby:
            second = 2
        SLIM
        result = described_class.call(
          RuboCop::ProcessedSource.new(source, 3.1, file_path)
        )

        expect(result.map { |clip| clip[:processed_source].raw_source }).to eq([
                                                                                 '  first = 1',
                                                                                 '  second = 2'
                                                                               ])
        expect(result.map { |clip| clip[:offset] }).to eq([
                                                            source.index('  first = 1'),
                                                            source.index('  second = 2')
                                                          ])
      end

      it 'extracts non-Ruby filter interpolations once without splitting Ruby filters' do
        source = <<~SLIM
          javascript:
            const name = "\#{user.name}"
          ruby:
            greeting = "Hello \#{name}"
        SLIM
        result = described_class.call(
          RuboCop::ProcessedSource.new(source, 3.1, file_path)
        )

        expect(result.map { |clip| clip[:processed_source].raw_source }).to eq([
                                                                                 'user.name',
                                                                                 '  greeting = "Hello #{name}"'
                                                                               ])
        expect(result.map { |clip| clip[:offset] }).to eq([
                                                            source.index('user.name'),
                                                            source.index('  greeting')
                                                          ])
      end

      it 'ignores blank bodies, non-Ruby filters, and inline filter attributes' do
        source = <<~SLIM
          ruby:
          javascript:
            const a = 1
          ruby: a = 1
        SLIM
        result = described_class.call(
          RuboCop::ProcessedSource.new(source, 3.1, file_path)
        )

        expect(result).to be_empty
      end
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
