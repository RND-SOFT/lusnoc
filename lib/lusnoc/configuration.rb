require 'logger'

module Lusnoc
  # Methods for configuring Lusnoc
  class Configuration

    attr_accessor :url, :acl_token, :logger

    # Override defaults for configuration
    # @param url [String] consul's connection URL
    # @param acl_token [String] a connection token used when making requests to consul
    def initialize(url = 'http://localhost:8500', acl_token = nil)
      @url = url
      @acl_token = acl_token
      @logger = Logger.new(STDOUT, level: Logger::INFO, progname: 'Lusnoc')
    end

  end
end

