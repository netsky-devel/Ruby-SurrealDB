require_relative 'lib/surrealdb/version'

Gem::Specification.new do |spec|
  spec.name          = 'surrealdb'
  spec.version       = SurrealDB::VERSION
  spec.authors       = ['Netsky Developer']
  spec.email         = ['netsky_devel@proton.me']

  spec.summary       = 'Ruby API wrapper for SurrealDB'
  spec.description   = 'A clean and comprehensive Ruby client library for SurrealDB with support for HTTP and WebSocket connections'
  spec.homepage      = 'https://github.com/netsky-devel/Ruby-SurrealDB'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/netsky-devel/Ruby-SurrealDB'
  spec.metadata['changelog_uri'] = 'https://github.com/netsky-devel/Ruby-SurrealDB/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'http', '~> 5.0'
  spec.add_dependency 'websocket-client-simple', '~> 0.6'
  spec.add_dependency 'json', '~> 2.0'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'yard', '~> 0.9'
end 