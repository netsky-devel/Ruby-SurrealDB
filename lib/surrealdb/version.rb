# frozen_string_literal: true

module SurrealDB
  # Current version of the SurrealDB Ruby client library
  # Follows semantic versioning (MAJOR.MINOR.PATCH)
  VERSION = '1.0.0'

  # Returns the current version string
  # @return [String] the version string
  def self.version
    VERSION
  end

  # Returns version information as a hash
  # @return [Hash] version components
  def self.version_info
    major, minor, patch = VERSION.split('.').map(&:to_i)
    {
      major: major,
      minor: minor,
      patch: patch,
      full: VERSION
    }
  end
end