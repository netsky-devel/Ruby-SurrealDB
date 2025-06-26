require 'spec_helper'

RSpec.describe SurrealDB::QueryBuilder do
  let(:mock_client) { double('SurrealDB::Client') }
  let(:query_builder) { described_class.new(mock_client) }
  let(:expected_variables) { {} }

  shared_examples 'builds correct SQL' do |expected_sql|
    it "builds correct SQL: #{expected_sql}" do
      expect(subject.to_sql).to eq(expected_sql)
    end
  end

  shared_examples 'stores variables correctly' do |expected_vars|
    it 'stores variables correctly' do
      subject
      expect(query_builder.instance_variable_get(:@variables)).to eq(expected_vars)
    end
  end

  shared_examples 'executes query with client' do |expected_sql, expected_vars = {}|
    it 'executes query with correct parameters' do
      expect(mock_client).to receive(:query).with(expected_sql, expected_vars)
      subject
    end
  end

  describe '#select' do
    context 'when selecting all fields' do
      subject { query_builder.select }
      include_examples 'builds correct SQL', 'SELECT *'
    end

    context 'when selecting specific fields' do
      subject { query_builder.select('name', 'age') }
      include_examples 'builds correct SQL', 'SELECT name, age'
    end
  end

  describe '#from' do
    context 'when adding FROM clause' do
      subject { query_builder.select.from('users') }
      include_examples 'builds correct SQL', 'SELECT * FROM users'
    end
  end

  describe '#where' do
    context 'when adding WHERE clause' do
      subject { query_builder.select.from('users').where('age > 18') }
      include_examples 'builds correct SQL', 'SELECT * FROM users WHERE age > 18'
    end

    context 'when adding WHERE clause with variables' do
      subject { query_builder.select.from('users').where('name = $name', {name: 'John'}) }
      include_examples 'stores variables correctly', {name: 'John'}
    end
  end

  describe '#order_by' do
    context 'when ordering with default ASC' do
      subject { query_builder.select.from('users').order_by('name') }
      include_examples 'builds correct SQL', 'SELECT * FROM users ORDER BY name ASC'
    end

    context 'when ordering with DESC' do
      subject { query_builder.select.from('users').order_by('age', 'DESC') }
      include_examples 'builds correct SQL', 'SELECT * FROM users ORDER BY age DESC'
    end
  end

  describe '#limit' do
    context 'when adding LIMIT clause' do
      subject { query_builder.select.from('users').limit(10) }
      include_examples 'builds correct SQL', 'SELECT * FROM users LIMIT 10'
    end
  end

  describe '#group_by' do
    context 'when grouping by single field' do
      subject { query_builder.select.from('users').group_by('department') }
      include_examples 'builds correct SQL', 'SELECT * FROM users GROUP BY department'
    end

    context 'when grouping by multiple fields' do
      subject { query_builder.select.from('users').group_by('department', 'role') }
      include_examples 'builds correct SQL', 'SELECT * FROM users GROUP BY department, role'
    end
  end

  describe '#having' do
    context 'when adding HAVING clause' do
      subject { query_builder.select.from('users').group_by('department').having('count(*) > 5') }
      include_examples 'builds correct SQL', 'SELECT * FROM users GROUP BY department HAVING count(*) > 5'
    end
  end

  describe '#insert' do
    let(:user_data_hash) { {name: 'John', age: 30} }
    let(:user_data_array) { [{name: 'John'}, {name: 'Jane'}] }

    context 'when inserting hash data' do
      subject { query_builder.insert('users', user_data_hash) }
      include_examples 'builds correct SQL', 'INSERT INTO users (name, age) VALUES ($name, $age)'
      include_examples 'stores variables correctly', {name: 'John', age: 30}
    end

    context 'when inserting array data' do
      subject { query_builder.insert('users', user_data_array) }
      include_examples 'builds correct SQL', "INSERT INTO users #{user_data_array.to_json}"
    end

    context 'when inserting without data' do
      subject { query_builder.insert('users') }
      include_examples 'builds correct SQL', 'INSERT INTO users'
    end
  end

  describe '#update' do
    let(:update_data) { {name: 'John', age: 30} }

    context 'when updating with data' do
      subject { query_builder.update('users', update_data) }
      include_examples 'builds correct SQL', 'UPDATE users SET name = $name, age = $age'
      include_examples 'stores variables correctly', {name: 'John', age: 30}
    end

    context 'when updating without data' do
      subject { query_builder.update('users') }
      include_examples 'builds correct SQL', 'UPDATE users'
    end
  end

  describe '#set' do
    let(:set_data) { {name: 'John', age: 30} }

    context 'when adding SET clause' do
      subject { query_builder.update('users').set(set_data) }
      include_examples 'builds correct SQL', 'UPDATE users SET name = $name, age = $age'
      include_examples 'stores variables correctly', {name: 'John', age: 30}
    end
  end

  describe '#delete' do
    context 'when deleting from specific table' do
      subject { query_builder.delete('users') }
      include_examples 'builds correct SQL', 'DELETE FROM users'
    end

    context 'when deleting without table specification' do
      subject { query_builder.delete }
      include_examples 'builds correct SQL', 'DELETE'
    end
  end

  describe '#create_table' do
    let(:table_schema) { {name: 'string', age: 'int'} }

    context 'when creating table with schema' do
      subject { query_builder.create_table('users', table_schema) }
      include_examples 'builds correct SQL', "CREATE TABLE users #{table_schema.to_json}"
    end

    context 'when creating table without schema' do
      subject { query_builder.create_table('users') }
      include_examples 'builds correct SQL', 'CREATE TABLE users'
    end
  end

  describe '#drop_table' do
    context 'when dropping table' do
      subject { query_builder.drop_table('users') }
      include_examples 'builds correct SQL', 'DROP TABLE users'
    end
  end

  describe '#raw' do
    let(:raw_sql) { 'SELECT custom_function()' }
    let(:raw_variables) { {id: 1} }

    context 'when adding raw SQL' do
      subject { query_builder.raw(raw_sql) }
      include_examples 'builds correct SQL', 'SELECT custom_function()'
    end

    context 'when adding raw SQL with variables' do
      subject { query_builder.raw('SELECT * FROM users WHERE id = $id', raw_variables) }
      include_examples 'stores variables correctly', {id: 1}
    end
  end

  describe '#execute' do
    let(:mock_query_result) { double('QueryResult') }

    before do
      allow(mock_client).to receive(:query).and_return(mock_query_result)
    end

    context 'when executing valid query' do
      subject { query_builder.select.from('users').execute }
      include_examples 'executes query with client', 'SELECT * FROM users', {}
    end

    context 'when executing empty query' do
      it 'raises QueryError for empty query' do
        expect { query_builder.execute }.to raise_error(SurrealDB::QueryError, 'Empty query')
      end
    end
  end

  describe '#first' do
    let(:first_result) { {'id' => 'user:1'} }
    let(:mock_query_result) { double('QueryResult', first: first_result) }

    before do
      allow(mock_client).to receive(:query).and_return(mock_query_result)
    end

    it 'executes query and returns first result' do
      query_builder.select.from('users')
      result = query_builder.first
      expect(result).to eq(first_result)
    end
  end

  describe '#all' do
    let(:all_results) { [{'id' => 'user:1'}, {'id' => 'user:2'}] }
    let(:mock_query_result) { double('QueryResult', all: all_results) }

    before do
      allow(mock_client).to receive(:query).and_return(mock_query_result)
    end

    it 'executes query and returns all results' do
      query_builder.select.from('users')
      result = query_builder.all
      expect(result).to eq(all_results)
    end
  end

  describe 'method chaining' do
    let(:chain_variables) { {min_age: 18} }
    let(:expected_chained_sql) { 'SELECT name, age FROM users WHERE age > $min_age ORDER BY name ASC LIMIT 10' }

    context 'when building complex chained query' do
      subject do
        query_builder
          .select('name', 'age')
          .from('users')
          .where('age > $min_age', chain_variables)
          .order_by('name')
          .limit(10)
      end

      include_examples 'builds correct SQL', 'SELECT name, age FROM users WHERE age > $min_age ORDER BY name ASC LIMIT 10'
      include_examples 'stores variables correctly', {min_age: 18}
    end
  end
end