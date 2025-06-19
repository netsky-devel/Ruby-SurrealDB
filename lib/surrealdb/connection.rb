require 'http'
require 'websocket-client-simple'
require 'json'
require 'uri'

module SurrealDB
  # Connection handler for SurrealDB
  class Connection
    attr_reader :url, :namespace, :database

    def initialize(url, **options)
      @url = url
      @options = options
      @timeout = options[:timeout] || 10
      @namespace = options[:namespace]
      @database = options[:database]
      @username = options[:username]
      @password = options[:password]
      @auth_token = nil
      
      # Determine connection type based on URL
      uri = URI.parse(url)
      @connection_type = uri.scheme == 'ws' || uri.scheme == 'wss' ? :websocket : :http
      
      initialize_connection
    end

    # Execute a query
    # @param query [String] SQL query to execute
    # @param variables [Hash] Query variables
    # @return [Hash] Raw response from SurrealDB
    def query(query, variables = {})
      case @connection_type
      when :http
        http_query(query, variables)
      when :websocket
        websocket_query(query, variables)
      else
        raise ConnectionError, "Unsupported connection type: #{@connection_type}"
      end
    end

    # Sign in with credentials
    # @param username [String] Username
    # @param password [String] Password
    # @return [Boolean] Success status
    def signin(username, password)
      @username = username
      @password = password
      
      case @connection_type
      when :http
        http_signin(username, password)
      when :websocket
        websocket_signin(username, password)
      end
    end

    # Use namespace and database
    # @param namespace [String] Namespace name
    # @param database [String] Database name
    def use(namespace, database)
      @namespace = namespace
      @database = database
      
      case @connection_type
      when :websocket
        websocket_use(namespace, database)
      end
    end

    # Close the connection
    def close
      case @connection_type
      when :websocket
        @websocket&.close
      end
    end

    # Check if connection is alive
    # @return [Boolean] Connection status
    def alive?
      case @connection_type
      when :http
        begin
          response = HTTP.timeout(@timeout).get("#{@url}/health")
          response.status.success?
        rescue
          false
        end
      when :websocket
        @websocket && @websocket.open?
      else
        false
      end
    end

    private

    def initialize_connection
      case @connection_type
      when :websocket
        initialize_websocket
      end
    end

    def initialize_websocket
      @websocket = WebSocket::Client::Simple.connect(@url)
      @message_id = 0
      @pending_requests = {}
      
      @websocket.on :message do |msg|
        handle_websocket_message(msg.data)
      end
      
      @websocket.on :error do |e|
        raise ConnectionError, "WebSocket error: #{e.message}"
      end
      
      # Wait for connection to establish
      sleep(0.1)
      raise ConnectionError, "Failed to establish WebSocket connection" unless @websocket.open?
    end

    def handle_websocket_message(data)
      message = JSON.parse(data)
      id = message['id']
      
      if @pending_requests[id]
        @pending_requests[id][:result] = message
        @pending_requests[id][:completed] = true
      end
    rescue JSON::ParserError
      # Ignore invalid JSON messages
    end

    def http_query(query, variables)
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
      
      headers['Authorization'] = "Bearer #{@auth_token}" if @auth_token
      headers['Surreal-NS'] = @namespace if @namespace
      headers['Surreal-DB'] = @database if @database
      
      body = {
        query: query,
        variables: variables
      }.to_json
      
      response = HTTP.timeout(@timeout)
                     .headers(headers)
                     .post("#{@url}/sql", body: body)
      
      unless response.status.success?
        raise QueryError, "HTTP #{response.status}: #{response.body}"
      end
      
      JSON.parse(response.body.to_s)
    rescue HTTP::Error => e
      raise ConnectionError, "HTTP connection error: #{e.message}"
    rescue JSON::ParserError => e
      raise QueryError, "Invalid JSON response: #{e.message}"
    end

    def http_signin(username, password)
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
      
      body = {
        user: username,
        pass: password
      }.to_json
      
      response = HTTP.timeout(@timeout)
                     .headers(headers)
                     .post("#{@url}/signin", body: body)
      
      if response.status.success?
        result = JSON.parse(response.body.to_s)
        @auth_token = result['token'] if result['token']
        true
      else
        raise AuthenticationError, "Authentication failed: #{response.body}"
      end
    rescue HTTP::Error => e
      raise ConnectionError, "HTTP connection error: #{e.message}"
    end

    def websocket_query(query, variables)
      send_websocket_message('query', { sql: query, vars: variables })
    end

    def websocket_signin(username, password)
      result = send_websocket_message('signin', { user: username, pass: password })
      @auth_token = result['result'] if result['result']
      true
    rescue => e
      raise AuthenticationError, "Authentication failed: #{e.message}"
    end

    def websocket_use(namespace, database)
      send_websocket_message('use', { ns: namespace, db: database })
    end

    def send_websocket_message(method, params = {})
      @message_id += 1
      id = @message_id.to_s
      
      message = {
        id: id,
        method: method,
        params: [params]
      }
      
      @pending_requests[id] = { completed: false, result: nil }
      @websocket.send(message.to_json)
      
      # Wait for response
      timeout = Time.now + @timeout
      while Time.now < timeout && !@pending_requests[id][:completed]
        sleep(0.01)
      end
      
      unless @pending_requests[id][:completed]
        @pending_requests.delete(id)
        raise TimeoutError, "Request timeout after #{@timeout} seconds"
      end
      
      result = @pending_requests[id][:result]
      @pending_requests.delete(id)
      
      if result['error']
        raise QueryError, result['error']['message'] || result['error'].to_s
      end
      
      result
    end
  end
end 