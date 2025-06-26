require 'spec_helper'

RSpec.describe SurrealDB do
  let(:default_url) { 'http://localhost:8000' }
  let(:connection_timeout) { 5 }

  describe '.connect' do
    context 'when creating a client instance' do
      subject(:client) { SurrealDB.connect(default_url) }

      it 'returns a SurrealDB::Client instance' do
        expect(client).to be_a(SurrealDB::Client)
      end
    end

    context 'when passing options to the client' do
      subject(:client) { SurrealDB.connect(default_url, timeout: connection_timeout) }

      it 'configures client with provided timeout option' do
        expect(client.connection.timeout).to eq(connection_timeout)
      end
    end
  end

  describe '.version' do
    subject(:version) { SurrealDB::VERSION }

    it 'is defined' do
      expect(version).not_to be_nil
    end

    it 'follows semantic versioning format' do
      expect(version).to match(semantic_version_pattern)
    end

    private

    def semantic_version_pattern
      /\A\d+\.\d+\.\d+\z/
    end
  end

  private

  # Encapsulates timeout extraction logic to avoid direct instance variable access
  def extract_timeout_from_client(client)
    client.connection.timeout
  end
end