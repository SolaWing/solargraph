require 'bundler/setup'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

require 'pry'
require 'simplecov'
SimpleCov.start

require 'solargraph'
# Suppress logger output in specs (if possible)
Solargraph::Logging.logger.reopen(File::NULL) if Solargraph::Logging.logger.respond_to?(:reopen)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
