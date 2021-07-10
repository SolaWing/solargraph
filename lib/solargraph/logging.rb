# frozen_string_literal: true

require 'logger'

module Solargraph
  module Logging
    DEFAULT_LOG_LEVEL = Logger::WARN

    LOG_LEVELS = {
      'warn' => Logger::WARN,
      'info' => Logger::INFO,
      'debug' => Logger::DEBUG
    }

    @@logger = Logger.new(STDERR, level: DEFAULT_LOG_LEVEL)
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{severity}](#{datetime.strftime("%j %H:%M:%S.%L")}) #{msg}\n"
    end

    module_function

    # @return [Logger]
    def logger
      @@logger
    end
  end
end
