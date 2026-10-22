require 'logger'

module Lusnoc
  # Methods for configuring Lusnoc
  class Configuration

    attr_accessor :url, :acl_token, :logger, :http_timeout

    # Get the most appropriate consul agent value from env
    # Parse the environment variable `CONSUL_HTTP_ADDR` and prefixes it with http:// if needed
    # Return default http://localhost:8500 if not found
    def self.parse_consul_addr
      ret = ENV['CONSUL_HTTP_ADDR'] || 'http://localhost:8500'
      ret = "http://#{ret}" unless ret.start_with?('http://', 'https://')
      ret
    end


    # Override defaults for configuration
    # @param url [String] consul's connection URL
    # @param acl_token [String] a connection token used when making requests to consul
    def initialize(url = Configuration.parse_consul_addr, acl_token = ENV['CONSUL_HTTP_TOKEN'])
      @url = url
      @acl_token = acl_token
      @logger = Logger.new(STDOUT, level: Logger::INFO, progname: 'Lusnoc')
      @http_timeout = 5
    end

  end
end

