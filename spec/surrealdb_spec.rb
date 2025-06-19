require 'spec_helper'

RSpec.describe SurrealDB do
  describe '.connect' do
    it 'creates a new client instance' do
      client = SurrealDB.connect('http://localhost:8000')
      expect(client).to be_a(SurrealDB::Client)
    end

    it 'passes options to the client' do
      client = SurrealDB.connect('http://localhost:8000', timeout: 5)
      expect(client.connection.instance_variable_get(:@timeout)).to eq(5)
    end
  end

  describe 'version' do
    it 'has a version number' do
      expect(SurrealDB::VERSION).not_to be nil
      expect(SurrealDB::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end 