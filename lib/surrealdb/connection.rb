# frozen_string_literal: true

require 'http'
require 'websocket-client-simple'
require 'json'
require 'uri'
require 'net/http'
require_relative 'error'
require_relative 'result'
require_relative 'connection/url_parser'
require_relative 'connection/http_client'
require_relative 'connection/websocket_client'
require_relative 'connection/endpoint_mapper'
require_relative 'connection/authentication_handler'

module SurrealDB
  # Main connection orchestrator that delegates to appropriate transport clients
  class Connection
    attr_reader :url, :protocol, :host, :port, :path, :timeout
    attr_accessor :authenticated, :auth_token

    def initialize(url:, timeout: 30, **options)
      @url = url
      @timeout = timeout
      @options = options
      @authenticated = false
      @auth_token = nil
      
      setup_connection_components
    end

    def connect
      transport_client.connect
    end

    def connected?
      transport_client.connected?
    end

    def websocket?
      protocol == 'ws' || protocol == 'wss'
    end

    def http?
      protocol == 'http' || protocol == 'https'
    end

    def query(method, *params)
      transport_client.execute_query(method, *params)
    end

    def close
      transport_client.close
    end

    private

    def setup_connection_components
      @url_parser = UrlParser.new(@url, @options)
      @protocol = @url_parser.protocol
      @host = @url_parser.host
      @port = @url_parser.port
      @path = @url_parser.path
      
      @authentication_handler = AuthenticationHandler.new(@options)
      @endpoint_mapper = EndpointMapper.new
    end

    def transport_client
      @transport_client ||= create_transport_client
    end

    def create_transport_client
      if websocket?
        WebsocketClient.new(
          url_parser: @url_parser,
          timeout: @timeout,
          options: @options,
          authentication_handler: @authentication_handler
        )
      else
        HttpClient.new(
          url_parser: @url_parser,
          timeout: @timeout,
          endpoint_mapper: @endpoint_mapper,
          authentication_handler: @authentication_handler
        )
      end
    end
  end
end