module SurrealDB
  # Wrapper class for SurrealDB query results
  class Result
    attr_reader :data, :time, :status

    def initialize(response)
      @raw_response = response
      parse_response(response)
    end

    # Check if the query was successful
    # @return [Boolean] true if successful, false otherwise
    def success?
      @status == 'OK'
    end

    # Check if the query failed
    # @return [Boolean] true if failed, false otherwise
    def error?
      !success?
    end

    # Get the first result
    # @return [Hash, nil] the first result or nil if empty
    def first
      return nil if @data.nil? || @data.empty?
      @data.first
    end

    # Get all results
    # @return [Array] array of results
    def all
      @data || []
    end

    # Check if results are empty
    # @return [Boolean] true if empty, false otherwise
    def empty?
      @data.nil? || @data.empty?
    end

    # Get the number of results
    # @return [Integer] number of results
    def count
      return 0 if @data.nil?
      @data.is_a?(Array) ? @data.length : 1
    end

    alias size count
    alias length count

    # Convert to array
    # @return [Array] array representation of results
    def to_a
      all
    end

    # Convert to hash (for single results)
    # @return [Hash] hash representation of the first result
    def to_h
      first || {}
    end

    # Iterate over results
    def each(&block)
      return enum_for(:each) unless block_given?
      all.each(&block)
    end

    private

    def parse_response(response)
      if response.is_a?(Hash)
        @data = response['result']
        @time = response['time']
        @status = response['status']
      elsif response.is_a?(Array)
        # Handle array of results
        @data = response
        @status = 'OK'
        @time = nil
      else
        @data = response
        @status = 'OK'
        @time = nil
      end
    end
  end
end 