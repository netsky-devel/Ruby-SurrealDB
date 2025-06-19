# frozen_string_literal: true

require 'http'
require 'websocket-client-simple'
require 'json'
require 'uri'
require 'net/http'
require_relative 'error'
require_relative 'result'

module SurrealDB
  # Handles connections to SurrealDB via HTTP and WebSocket protocols
  class Connection
    attr_reader :url, :protocol, :host, :port, :path, :timeout
    attr_accessor :authenticated, :auth_token

    def initialize(url:, timeout: 30, **options)
      @url = url
      @timeout = timeout
      @options = options
      @authenticated = false
      @auth_token = nil
      @pending_requests = {}
      @request_id = 0
      @live_queries = {}
      
      parse_url
    end

    def connect
      case @protocol
      when 'http', 'https'
        # HTTP connections are stateless, no persistent connection needed
        @connected = true
      when 'ws', 'wss'
        connect_websocket
      else
        raise SurrealDB::ConnectionError, "Unsupported protocol: #{@protocol}"
      end
    end

    def connected?
      @connected || false
    end

    def websocket?
      @protocol == 'ws' || @protocol == 'wss'
    end

    def http?
      @protocol == 'http' || @protocol == 'https'
    end

    def query(method, *params)
      case @protocol
      when 'http', 'https'
        http_request(method, *params)
      when 'ws', 'wss'
        websocket_request(method, *params)
      else
        raise SurrealDB::ConnectionError, "Unsupported protocol: #{@protocol}"
      end
    end

    def close
      case @protocol
      when 'ws', 'wss'
        @ws&.close
        @connected = false
      when 'http', 'https'
        # HTTP connections don't need explicit closing
        @connected = false
      end
    end

    private

    def parse_url
      uri = URI.parse(@url)
      @protocol = uri.scheme
      @host = uri.host
      @port = uri.port
      @path = uri.path.empty? ? '/rpc' : uri.path
      
      # Convert HTTP schemes to WebSocket if needed
      if @protocol == 'http'
        @protocol = 'ws' if @options[:websocket]
      elsif @protocol == 'https'
        @protocol = 'wss' if @options[:websocket]
      end
    end

    def connect_websocket
      ws_url = "#{@protocol}://#{@host}:#{@port}#{@path}"
      
      begin
        @ws = WebSocket::Client::Simple.connect(ws_url)
        @connected = true
        
        setup_websocket_handlers
        
        # Wait for connection to be established
        sleep(0.1) until @ws.readyState == WebSocket::OPEN
        
      rescue => e
        raise SurrealDB::ConnectionError, "Failed to connect via WebSocket: #{e.message}"
      end
    end

    def setup_websocket_handlers
      @ws.on :message do |msg|
        handle_websocket_message(msg.data)
      end

      @ws.on :close do |e|
        @connected = false
        # Handle reconnection logic if needed
      end

      @ws.on :error do |e|
        raise SurrealDB::ConnectionError, "WebSocket error: #{e.message}"
      end
    end

    def handle_websocket_message(data)
      begin
        response = JSON.parse(data)
        
        if response['id']
          # Regular RPC response
          handle_rpc_response(response)
        else
          # Live query notification
          handle_live_notification(response)
        end
        
      rescue JSON::ParserError => e
        # Invalid JSON response
      end
    end

    def handle_rpc_response(response)
      request_id = response['id']
      
      if @pending_requests[request_id]
        promise = @pending_requests.delete(request_id)
        
        if response['error']
          promise.reject(SurrealDB::QueryError.new(response['error']['message']))
        else
          promise.resolve(Result.new(response['result']))
        end
      end
    end

    def handle_live_notification(response)
      # Handle live query notifications
      # You can implement callbacks or event handling here
      if @options[:on_live_notification]
        @options[:on_live_notification].call(response)
      end
    end

    def websocket_request(method, *params)
      raise SurrealDB::ConnectionError, "WebSocket not connected" unless @connected

      request_id = next_request_id
      
      request = {
        id: request_id,
        method: method,
        params: params.compact
      }

      @ws.send(JSON.generate(request))
      
      # Create a simple promise-like object
      promise = Promise.new
      @pending_requests[request_id] = promise
      
      # Wait for response with timeout
      result = promise.wait(@timeout)
      
      if result.nil?
        @pending_requests.delete(request_id)
        raise SurrealDB::TimeoutError, "Request timed out after #{@timeout} seconds"
      end
      
      result
    end

    def http_request(method, *params)
      endpoint = map_method_to_endpoint(method, params)
      http_method = endpoint[:method]
      path = endpoint[:path]
      body = endpoint[:body]
      headers = endpoint[:headers] || {}

      # Add authentication headers
      headers.merge!(auth_headers) if @authenticated

      begin
        uri = URI("#{@protocol}://#{@host}:#{@port}#{path}")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (@protocol == 'https')
        http.read_timeout = @timeout
        
        request = case http_method
                  when 'GET'
                    Net::HTTP::Get.new(uri)
                  when 'POST'
                    Net::HTTP::Post.new(uri)
                  when 'PUT'
                    Net::HTTP::Put.new(uri)
                  when 'PATCH'
                    Net::HTTP::Patch.new(uri)
                  when 'DELETE'
                    Net::HTTP::Delete.new(uri)
                  else
                    raise SurrealDB::ConnectionError, "Unsupported HTTP method: #{http_method}"
                  end

        # Set headers
        headers.each { |key, value| request[key] = value }
        
        # Set body for POST/PUT/PATCH requests
        if body && %w[POST PUT PATCH].include?(http_method)
          request.body = body.is_a?(String) ? body : JSON.generate(body)
          request['Content-Type'] = 'application/json' unless request['Content-Type']
        end

        response = http.request(request)
        
        handle_http_response(response)
        
      rescue Net::TimeoutError
        raise SurrealDB::TimeoutError, "HTTP request timed out after #{@timeout} seconds"
      rescue => e
        raise SurrealDB::ConnectionError, "HTTP request failed: #{e.message}"
      end
    end

    def map_method_to_endpoint(method, params)
      case method
      when 'signin', 'signup'
        {
          method: 'POST',
          path: "/#{method}",
          body: params.first,
          headers: { 'Accept' => 'application/json' }
        }
      when 'query'
        sql = params[0]
        vars = params[1] || {}
        query_params = vars.empty? ? '' : '?' + URI.encode_www_form(vars)
        
        {
          method: 'POST',
          path: "/sql#{query_params}",
          body: sql,
          headers: { 
            'Accept' => 'application/json',
            'Content-Type' => 'text/plain'
          }
        }
      when 'graphql'
        {
          method: 'POST',
          path: '/graphql',
          body: params.first,
          headers: { 'Accept' => 'application/json' }
        }
      when 'select'
        table_or_record = params[0]
        if table_or_record.include?(':')
          # Selecting specific record
          table, id = table_or_record.split(':', 2)
          { method: 'GET', path: "/key/#{table}/#{id}" }
        else
          # Selecting from table
          { method: 'GET', path: "/key/#{table_or_record}" }
        end
      when 'create'
        table = params[0]
        data = params[1]
        
        {
          method: 'POST',
          path: "/key/#{table}",
          body: data,
          headers: { 'Accept' => 'application/json' }
        }
      when 'update'
        table_or_record = params[0]
        data = params[1]
        
        if table_or_record.include?(':')
          table, id = table_or_record.split(':', 2)
          path = "/key/#{table}/#{id}"
        else
          path = "/key/#{table_or_record}"
        end
        
        {
          method: 'PUT',
          path: path,
          body: data,
          headers: { 'Accept' => 'application/json' }
        }
      when 'delete'
        table_or_record = params[0]
        
        if table_or_record.include?(':')
          table, id = table_or_record.split(':', 2)
          path = "/key/#{table}/#{id}"
        else
          path = "/key/#{table_or_record}"
        end
        
        { method: 'DELETE', path: path }
      when 'version'
        { method: 'GET', path: '/version' }
      when 'ping', 'health'
        { method: 'GET', path: '/health' }
      else
        # Fallback to RPC over HTTP (if supported)
        {
          method: 'POST',
          path: '/rpc',
          body: { method: method, params: params },
          headers: { 'Accept' => 'application/json' }
        }
      end
    end

    def handle_http_response(response)
      case response.code.to_i
      when 200..299
        content_type = response['content-type'] || ''
        
        if content_type.include?('application/json') && !response.body.empty?
          data = JSON.parse(response.body)
          Result.new(data)
        else
          Result.new(response.body)
        end
      when 400..499
        error_message = extract_error_message(response)
        raise SurrealDB::QueryError, "Client error (#{response.code}): #{error_message}"
      when 500..599
        error_message = extract_error_message(response)
        raise SurrealDB::QueryError, "Server error (#{response.code}): #{error_message}"
      else
        raise SurrealDB::ConnectionError, "Unexpected response code: #{response.code}"
      end
    end

    def extract_error_message(response)
      if response['content-type']&.include?('application/json') && !response.body.empty?
        begin
          error_data = JSON.parse(response.body)
          error_data['message'] || error_data['error'] || response.body
        rescue JSON::ParserError
          response.body
        end
      else
        response.body || "HTTP #{response.code}"
      end
    end

    def auth_headers
      headers = {}
      
      if @auth_token
        headers['Authorization'] = "Bearer #{@auth_token}"
      end
      
      # Add namespace and database headers for SurrealDB 2.x
      if @options[:namespace]
        headers['Surreal-NS'] = @options[:namespace]
      end
      
      if @options[:database]
        headers['Surreal-DB'] = @options[:database]
      end
      
      headers
    end

    def next_request_id
      @request_id += 1
    end

    # Simple Promise-like implementation for WebSocket requests
    class Promise
      def initialize
        @resolved = false
        @rejected = false
        @value = nil
        @error = nil
      end

      def resolve(value)
        @resolved = true
        @value = value
      end

      def reject(error)
        @rejected = true
        @error = error
      end

      def wait(timeout)
        start_time = Time.now
        
        while !@resolved && !@rejected
          sleep(0.01)
          if Time.now - start_time > timeout
            return nil
          end
        end
        
        if @rejected
          raise @error
        else
          @value
        end
      end
    end
  end
end 
end 