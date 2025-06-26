require 'spec_helper'

RSpec.describe SurrealDB::Result do
  let(:sample_user_data) { [{ 'id' => 'user:1', 'name' => 'John' }] }
  let(:multiple_users_data) do
    [
      { 'id' => 'user:1', 'name' => 'John' },
      { 'id' => 'user:2', 'name' => 'Jane' }
    ]
  end

  shared_examples 'successful result' do
    it 'indicates success status' do
      expect(subject.success?).to be true
      expect(subject.error?).to be false
    end
  end

  shared_examples 'data accessor' do |expected_data|
    it 'provides correct data access' do
      expect(subject.data).to eq(expected_data)
    end
  end

  shared_examples 'enumerable behavior' do |expected_data|
    it 'behaves as enumerable collection' do
      expect(subject.count).to eq(expected_data.size)
      expect(subject.size).to eq(expected_data.size)
      expect(subject.length).to eq(expected_data.size)
      expect(subject.to_a).to eq(expected_data)
    end

    it 'supports iteration' do
      collected_results = []
      subject.each { |result| collected_results << result }
      expect(collected_results).to eq(expected_data)
    end

    it 'returns enumerator when no block given to each' do
      expect(subject.each).to be_a(Enumerator)
    end
  end

  describe '#initialize' do
    context 'when initialized with hash response' do
      subject { create_result_with_hash_response }

      include_examples 'successful result'
      include_examples 'data accessor', [{ 'id' => 'user:1', 'name' => 'John' }]

      it 'extracts metadata from response' do
        expect(subject.time).to eq('100ms')
        expect(subject.status).to eq('OK')
      end
    end

    context 'when initialized with array response' do
      subject { create_result_with_array_response }

      include_examples 'data accessor', [{ 'id' => 'user:1', 'name' => 'John' }]

      it 'defaults status to OK for array responses' do
        expect(subject.status).to eq('OK')
      end
    end
  end

  describe '#first' do
    context 'when results contain data' do
      subject { create_result_with_multiple_users }

      it 'returns first result item' do
        expect(subject.first).to eq({ 'id' => 'user:1', 'name' => 'John' })
      end
    end

    context 'when results are empty' do
      subject { create_empty_result }

      it 'returns nil for empty results' do
        expect(subject.first).to be_nil
      end
    end
  end

  describe '#all' do
    subject { create_result_with_multiple_users }

    it 'returns all result items' do
      expect(subject.all).to eq(multiple_users_data)
    end
  end

  describe '#empty?' do
    context 'when results contain data' do
      subject { create_result_with_single_user }

      it 'returns false for non-empty results' do
        expect(subject.empty?).to be false
      end
    end

    context 'when results are empty' do
      subject { create_empty_result }

      it 'returns true for empty results' do
        expect(subject.empty?).to be true
      end
    end
  end

  describe 'enumerable interface' do
    subject { create_result_with_multiple_users }

    include_examples 'enumerable behavior', [
      { 'id' => 'user:1', 'name' => 'John' },
      { 'id' => 'user:2', 'name' => 'Jane' }
    ]
  end

  describe '#to_h' do
    context 'when results contain data' do
      subject { create_result_with_single_user }

      it 'returns hash representation of first result' do
        expect(subject.to_h).to eq({ 'id' => 'user:1', 'name' => 'John' })
      end
    end

    context 'when results are empty' do
      subject { create_empty_result }

      it 'returns empty hash for empty results' do
        expect(subject.to_h).to eq({})
      end
    end
  end

  private

  def create_result_with_hash_response
    response = {
      'result' => sample_user_data,
      'time' => '100ms',
      'status' => 'OK'
    }
    described_class.new(response)
  end

  def create_result_with_array_response
    described_class.new(sample_user_data)
  end

  def create_result_with_single_user
    response = {
      'result' => sample_user_data,
      'status' => 'OK'
    }
    described_class.new(response)
  end

  def create_result_with_multiple_users
    response = {
      'result' => multiple_users_data,
      'status' => 'OK'
    }
    described_class.new(response)
  end

  def create_empty_result
    response = {
      'result' => [],
      'status' => 'OK'
    }
    described_class.new(response)
  end
end