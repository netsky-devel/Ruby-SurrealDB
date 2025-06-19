require 'spec_helper'

RSpec.describe SurrealDB::QueryBuilder do
  let(:client) { double('client') }
  let(:builder) { described_class.new(client) }

  describe '#select' do
    it 'builds SELECT query with all fields' do
      result_sql = builder.select.to_sql
      expect(result_sql).to eq('SELECT *')
    end

    it 'builds SELECT query with specific fields' do
      result_sql = builder.select('name', 'age').to_sql
      expect(result_sql).to eq('SELECT name, age')
    end
  end

  describe '#from' do
    it 'adds FROM clause' do
      result_sql = builder.select.from('users').to_sql
      expect(result_sql).to eq('SELECT * FROM users')
    end
  end

  describe '#where' do
    it 'adds WHERE clause' do
      result_sql = builder.select.from('users').where('age > 18').to_sql
      expect(result_sql).to eq('SELECT * FROM users WHERE age > 18')
    end

    it 'stores variables' do
      builder.select.from('users').where('name = $name', {name: 'John'})
      expect(builder.instance_variable_get(:@variables)).to eq({name: 'John'})
    end
  end

  describe '#order_by' do
    it 'adds ORDER BY clause with default ASC' do
      result_sql = builder.select.from('users').order_by('name').to_sql
      expect(result_sql).to eq('SELECT * FROM users ORDER BY name ASC')
    end

    it 'adds ORDER BY clause with DESC' do
      result_sql = builder.select.from('users').order_by('age', 'DESC').to_sql
      expect(result_sql).to eq('SELECT * FROM users ORDER BY age DESC')
    end
  end

  describe '#limit' do
    it 'adds LIMIT clause' do
      result_sql = builder.select.from('users').limit(10).to_sql
      expect(result_sql).to eq('SELECT * FROM users LIMIT 10')
    end
  end

  describe '#group_by' do
    it 'adds GROUP BY clause' do
      result_sql = builder.select.from('users').group_by('department').to_sql
      expect(result_sql).to eq('SELECT * FROM users GROUP BY department')
    end

    it 'handles multiple fields' do
      result_sql = builder.select.from('users').group_by('department', 'role').to_sql
      expect(result_sql).to eq('SELECT * FROM users GROUP BY department, role')
    end
  end

  describe '#having' do
    it 'adds HAVING clause' do
      result_sql = builder.select.from('users').group_by('department').having('count(*) > 5').to_sql
      expect(result_sql).to eq('SELECT * FROM users GROUP BY department HAVING count(*) > 5')
    end
  end

  describe '#insert' do
    context 'with hash data' do
      it 'builds INSERT query with placeholders' do
        result_sql = builder.insert('users', {name: 'John', age: 30}).to_sql
        expect(result_sql).to eq('INSERT INTO users (name, age) VALUES ($name, $age)')
        expect(builder.instance_variable_get(:@variables)).to eq({name: 'John', age: 30})
      end
    end

    context 'with array data' do
      it 'builds INSERT query with JSON' do
        data = [{name: 'John'}, {name: 'Jane'}]
        result_sql = builder.insert('users', data).to_sql
        expect(result_sql).to eq("INSERT INTO users #{data.to_json}")
      end
    end

    context 'without data' do
      it 'builds basic INSERT query' do
        result_sql = builder.insert('users').to_sql
        expect(result_sql).to eq('INSERT INTO users')
      end
    end
  end

  describe '#update' do
    context 'with data' do
      it 'builds UPDATE query with SET clause' do
        result_sql = builder.update('users', {name: 'John', age: 30}).to_sql
        expect(result_sql).to eq('UPDATE users SET name = $name, age = $age')
        expect(builder.instance_variable_get(:@variables)).to eq({name: 'John', age: 30})
      end
    end

    context 'without data' do
      it 'builds basic UPDATE query' do
        result_sql = builder.update('users').to_sql
        expect(result_sql).to eq('UPDATE users')
      end
    end
  end

  describe '#set' do
    it 'adds SET clause' do
      result_sql = builder.update('users').set({name: 'John', age: 30}).to_sql
      expect(result_sql).to eq('UPDATE users SET name = $name, age = $age')
      expect(builder.instance_variable_get(:@variables)).to eq({name: 'John', age: 30})
    end
  end

  describe '#delete' do
    context 'with table' do
      it 'builds DELETE FROM query' do
        result_sql = builder.delete('users').to_sql
        expect(result_sql).to eq('DELETE FROM users')
      end
    end

    context 'without table' do
      it 'builds basic DELETE query' do
        result_sql = builder.delete.to_sql
        expect(result_sql).to eq('DELETE')
      end
    end
  end

  describe '#create_table' do
    context 'with schema' do
      it 'builds CREATE TABLE query with schema' do
        schema = {name: 'string', age: 'int'}
        result_sql = builder.create_table('users', schema).to_sql
        expect(result_sql).to eq("CREATE TABLE users #{schema.to_json}")
      end
    end

    context 'without schema' do
      it 'builds basic CREATE TABLE query' do
        result_sql = builder.create_table('users').to_sql
        expect(result_sql).to eq('CREATE TABLE users')
      end
    end
  end

  describe '#drop_table' do
    it 'builds DROP TABLE query' do
      result_sql = builder.drop_table('users').to_sql
      expect(result_sql).to eq('DROP TABLE users')
    end
  end

  describe '#raw' do
    it 'adds raw SQL' do
      result_sql = builder.raw('SELECT custom_function()').to_sql
      expect(result_sql).to eq('SELECT custom_function()')
    end

    it 'merges variables' do
      builder.raw('SELECT * FROM users WHERE id = $id', {id: 1})
      expect(builder.instance_variable_get(:@variables)).to eq({id: 1})
    end
  end

  describe '#execute' do
    let(:mock_result) { double('result') }

    before do
      allow(client).to receive(:query).and_return(mock_result)
    end

    it 'executes the query on the client' do
      builder.select.from('users')
      expect(client).to receive(:query).with('SELECT * FROM users', {})
      builder.execute
    end

    it 'raises error for empty query' do
      expect { builder.execute }.to raise_error(SurrealDB::QueryError, 'Empty query')
    end
  end

  describe '#first' do
    let(:mock_result) { double('result', first: {'id' => 'user:1'}) }

    before do
      allow(client).to receive(:query).and_return(mock_result)
    end

    it 'executes query and returns first result' do
      builder.select.from('users')
      result = builder.first
      expect(result).to eq({'id' => 'user:1'})
    end
  end

  describe '#all' do
    let(:mock_result) { double('result', all: [{'id' => 'user:1'}, {'id' => 'user:2'}]) }

    before do
      allow(client).to receive(:query).and_return(mock_result)
    end

    it 'executes query and returns all results' do
      builder.select.from('users')
      result = builder.all
      expect(result).to eq([{'id' => 'user:1'}, {'id' => 'user:2'}])
    end
  end

  describe 'method chaining' do
    it 'allows complex query building' do
      result_sql = builder
        .select('name', 'age')
        .from('users')
        .where('age > $min_age', {min_age: 18})
        .order_by('name')
        .limit(10)
        .to_sql

      expected = 'SELECT name, age FROM users WHERE age > $min_age ORDER BY name ASC LIMIT 10'
      expect(result_sql).to eq(expected)
      expect(builder.instance_variable_get(:@variables)).to eq({min_age: 18})
    end
  end
end 