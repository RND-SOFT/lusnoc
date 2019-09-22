require 'net/http'
require 'json'

require 'lusnoc/configuration'
require 'lusnoc/session'
require 'lusnoc/mutex'


module Lusnoc

  class << self

    attr_accessor :configuration

  end

  self.configuration ||= Lusnoc::Configuration.new

  class << self

    def configure
      self.configuration ||= Lusnoc::Configuration.new
      yield(configuration)
    end

    def http_get(url, timeout: 1)
      uri = URI(url)

      with_http(uri, timeout: timeout) do |http|
        req = Net::HTTP::Get.new(uri)

        # configure http and request before send
        yield(http, req) if block_given?
        http.request(req)
      end
    end

    def http_put(url, value = nil, timeout: 1)
      uri = URI(url)
      data = value.is_a?(String) ? value : JSON.generate(value) unless value.nil?

      with_http(uri, timeout: timeout) do |http|
        req = Net::HTTP::Put.new(uri).tap do |r|
          r.body = data
          r['Content-Type'] = 'application/json'
        end

        # configure http and request before send
        yield(http, req) if block_given?
        http.request(req)
      end
    end

    private

      def with_http(uri, timeout:)
        Net::HTTP.start(uri.host, uri.port,
                        use_ssl:          uri.scheme == 'https',
                        read_timeout:     timeout,
                        open_timeout:     1,
                        continue_timeout: 1,
                        write_timeout:    1,
                        max_retries:      0) do |http|
          yield(http)
        end
      end

  end

end

