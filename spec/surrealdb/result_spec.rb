require 'spec_helper'

RSpec.describe SurrealDB::Result do
  describe '#initialize' do
    context 'with hash response' do
      let(:response) do
        {
          'result' => [{'id' => 'user:1', 'name' => 'John'}],
          'time' => '100ms',
          'status' => 'OK'
        }
      end

      subject { described_class.new(response) }

      it 'parses the response correctly' do
        expect(subject.data).to eq([{'id' => 'user:1', 'name' => 'John'}])
        expect(subject.time).to eq('100ms')
        expect(subject.status).to eq('OK')
      end

      it 'indicates success' do
        expect(subject.success?).to be true
        expect(subject.error?).to be false
      end
    end

    context 'with array response' do
      let(:response) { [{'id' => 'user:1', 'name' => 'John'}] }
      subject { described_class.new(response) }

      it 'treats array as data' do
        expect(subject.data).to eq([{'id' => 'user:1', 'name' => 'John'}])
        expect(subject.status).to eq('OK')
      end
    end
  end

  describe '#first' do
    let(:response) do
      {
        'result' => [
          {'id' => 'user:1', 'name' => 'John'},
          {'id' => 'user:2', 'name' => 'Jane'}
        ],
        'status' => 'OK'
      }
    end

    subject { described_class.new(response) }

    it 'returns the first result' do
      expect(subject.first).to eq({'id' => 'user:1', 'name' => 'John'})
    end

    context 'with empty results' do
      let(:response) { {'result' => [], 'status' => 'OK'} }

      it 'returns nil' do
        expect(subject.first).to be_nil
      end
    end
  end

  describe '#all' do
    let(:response) do
      {
        'result' => [
          {'id' => 'user:1', 'name' => 'John'},
          {'id' => 'user:2', 'name' => 'Jane'}
        ],
        'status' => 'OK'
      }
    end

    subject { described_class.new(response) }

    it 'returns all results' do
      expect(subject.all).to eq([
        {'id' => 'user:1', 'name' => 'John'},
        {'id' => 'user:2', 'name' => 'Jane'}
      ])
    end
  end

  describe '#empty?' do
    context 'with results' do
      let(:response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }
      subject { described_class.new(response) }

      it 'returns false' do
        expect(subject.empty?).to be false
      end
    end

    context 'without results' do
      let(:response) { {'result' => [], 'status' => 'OK'} }
      subject { described_class.new(response) }

      it 'returns true' do
        expect(subject.empty?).to be true
      end
    end
  end

  describe '#count' do
    let(:response) do
      {
        'result' => [{'id' => 'user:1'}, {'id' => 'user:2'}],
        'status' => 'OK'
      }
    end

    subject { described_class.new(response) }

    it 'returns the count of results' do
      expect(subject.count).to eq(2)
      expect(subject.size).to eq(2)
      expect(subject.length).to eq(2)
    end
  end

  describe '#each' do
    let(:response) do
      {
        'result' => [{'id' => 'user:1'}, {'id' => 'user:2'}],
        'status' => 'OK'
      }
    end

    subject { described_class.new(response) }

    it 'iterates over results' do
      results = []
      subject.each { |result| results << result }
      expect(results).to eq([{'id' => 'user:1'}, {'id' => 'user:2'}])
    end

    it 'returns enumerator when no block given' do
      expect(subject.each).to be_a(Enumerator)
    end
  end

  describe '#to_a' do
    let(:response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }
    subject { described_class.new(response) }

    it 'returns array representation' do
      expect(subject.to_a).to eq([{'id' => 'user:1'}])
    end
  end

  describe '#to_h' do
    let(:response) { {'result' => [{'id' => 'user:1', 'name' => 'John'}], 'status' => 'OK'} }
    subject { described_class.new(response) }

    it 'returns hash representation of first result' do
      expect(subject.to_h).to eq({'id' => 'user:1', 'name' => 'John'})
    end

    context 'with empty results' do
      let(:response) { {'result' => [], 'status' => 'OK'} }

      it 'returns empty hash' do
        expect(subject.to_h).to eq({})
      end
    end
  end
end 