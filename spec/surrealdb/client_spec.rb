require 'spec_helper'

RSpec.describe SurrealDB::Client do
  let(:url) { 'http://localhost:8000' }
  let(:client) { described_class.new(url) }

  before do
    # Mock the connection initialization
    allow_any_instance_of(SurrealDB::Connection).to receive(:initialize_connection)
  end

  describe '#initialize' do
    it 'creates a connection' do
      expect(client.connection).to be_a(SurrealDB::Connection)
    end

    it 'auto-authenticates when credentials provided' do
      expect_any_instance_of(SurrealDB::Connection).to receive(:signin).with('user', 'pass')
      described_class.new(url, username: 'user', password: 'pass')
    end

    it 'auto-uses namespace and database when provided' do
      expect_any_instance_of(SurrealDB::Connection).to receive(:use).with('ns', 'db')
      described_class.new(url, namespace: 'ns', database: 'db')
    end
  end

  describe '#query' do
    let(:mock_response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    it 'executes query and returns Result object' do
      result = client.query('SELECT * FROM users')
      expect(result).to be_a(SurrealDB::Result)
      expect(result.success?).to be true
    end

    it 'passes variables to connection' do
      expect(client.connection).to receive(:query).with('SELECT * FROM users WHERE id = $id', {'id' => '1'})
      client.query('SELECT * FROM users WHERE id = $id', {'id' => '1'})
    end
  end

  describe '#query_builder' do
    it 'returns a new QueryBuilder instance' do
      builder = client.query_builder
      expect(builder).to be_a(SurrealDB::QueryBuilder)
    end
  end

  describe '#signin' do
    it 'delegates to connection' do
      expect(client.connection).to receive(:signin).with('user', 'pass')
      client.signin('user', 'pass')
    end
  end

  describe '#use' do
    it 'delegates to connection' do
      expect(client.connection).to receive(:use).with('ns', 'db')
      result = client.use('ns', 'db')
      expect(result).to be true
    end
  end

  describe '#create' do
    let(:mock_response) { {'result' => [{'id' => 'user:1', 'name' => 'John'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    context 'with data' do
      it 'creates record with SET clause' do
        expected_query = 'CREATE users SET name: $name, age: $age'
        expected_vars = {'name' => 'John', 'age' => '30'}
        
        expect(client.connection).to receive(:query).with(expected_query, expected_vars)
        client.create('users', {name: 'John', age: 30})
      end
    end

    context 'without data' do
      it 'creates empty record' do
        expect(client.connection).to receive(:query).with('CREATE users', {})
        client.create('users')
      end
    end
  end

  describe '#select' do
    let(:mock_response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    context 'without conditions' do
      it 'selects all records' do
        expect(client.connection).to receive(:query).with('SELECT * FROM users', {})
        client.select('users')
      end
    end

    context 'with conditions' do
      it 'selects records with WHERE clause' do
        expected_query = 'SELECT * FROM users WHERE name = $name AND age = $age'
        expected_vars = {'name' => 'John', 'age' => '30'}
        
        expect(client.connection).to receive(:query).with(expected_query, expected_vars)
        client.select('users', {name: 'John', age: 30})
      end
    end
  end

  describe '#update' do
    let(:mock_response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    context 'without conditions' do
      it 'updates all records' do
        expected_query = 'UPDATE users SET name = $name, age = $age'
        expected_vars = {'name' => 'John', 'age' => '30'}
        
        expect(client.connection).to receive(:query).with(expected_query, expected_vars)
        client.update('users', {name: 'John', age: 30})
      end
    end

    context 'with conditions' do
      it 'updates records with WHERE clause' do
        expected_query = 'UPDATE users SET name = $name WHERE id = $where_id'
        expected_vars = {'name' => 'John', 'where_id' => '1'}
        
        expect(client.connection).to receive(:query).with(expected_query, expected_vars)
        client.update('users', {name: 'John'}, {id: 1})
      end
    end
  end

  describe '#delete' do
    let(:mock_response) { {'result' => [], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    context 'without conditions' do
      it 'deletes all records' do
        expect(client.connection).to receive(:query).with('DELETE FROM users', {})
        client.delete('users')
      end
    end

    context 'with conditions' do
      it 'deletes records with WHERE clause' do
        expected_query = 'DELETE FROM users WHERE id = $id'
        expected_vars = {'id' => '1'}
        
        expect(client.connection).to receive(:query).with(expected_query, expected_vars)
        client.delete('users', {id: 1})
      end
    end
  end

  describe '#find' do
    let(:mock_response) { {'result' => [{'id' => 'user:1'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    it 'finds record by ID' do
      expect(client.connection).to receive(:query).with('SELECT * FROM users:1', {})
      client.find('users', '1')
    end
  end

  describe '#first' do
    let(:mock_response) { {'result' => [{'id' => 'user:1', 'name' => 'John'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    it 'returns first record as hash' do
      result = client.first('users')
      expect(result).to eq({'id' => 'user:1', 'name' => 'John'})
    end
  end

  describe '#all' do
    let(:mock_response) { {'result' => [{'id' => 'user:1'}, {'id' => 'user:2'}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    it 'returns all records as array' do
      result = client.all('users')
      expect(result).to eq([{'id' => 'user:1'}, {'id' => 'user:2'}])
    end
  end

  describe '#count' do
    let(:mock_response) { {'result' => [{'count' => 5}], 'status' => 'OK'} }

    before do
      allow(client.connection).to receive(:query).and_return(mock_response)
    end

    it 'returns count of records' do
      expect(client.connection).to receive(:query).with('SELECT count() FROM users GROUP ALL', {})
      result = client.count('users')
      expect(result).to eq(5)
    end
  end

  describe '#ping' do
    context 'when connection is alive' do
      before do
        allow(client.connection).to receive(:query).and_return({'result' => [1], 'status' => 'OK'})
      end

      it 'returns true' do
        expect(client.ping).to be true
      end
    end

    context 'when connection fails' do
      before do
        allow(client.connection).to receive(:query).and_raise(SurrealDB::ConnectionError)
      end

      it 'returns false' do
        expect(client.ping).to be false
      end
    end
  end

  describe '#alive?' do
    it 'delegates to connection' do
      expect(client.connection).to receive(:alive?)
      client.alive?
    end
  end

  describe '#close' do
    it 'delegates to connection' do
      expect(client.connection).to receive(:close)
      client.close
    end
  end
end 