require 'net/http'
require 'json'

require 'lusnoc/configuration'
require 'lusnoc/session'
require 'lusnoc/mutex'
require 'lusnoc/guard'


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

    def http_get(url, timeout: Lusnoc.configuration.http_timeout)
      uri = URI(url)

      with_http(uri, timeout: timeout) do |http|
        req = Net::HTTP::Get.new(uri)

        # configure http and request before send
        yield(http, req) if block_given?
        http.request(req)
      end
    end

    def http_put(url, value = nil, timeout: Lusnoc.configuration.http_timeout)
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
        with_retry(delay: 0.1) do
          Net::HTTP.start(uri.host, uri.port,
                          use_ssl:          uri.scheme == 'https',
                          read_timeout:     timeout,
                          open_timeout:     timeout,
                          continue_timeout: timeout,
                          write_timeout:    timeout,
                          max_retries:      1) do |http|
            yield(http)
          end
        end
      end

      def with_retry(count = 2, delay: 1, klass: nil)
        begin
          retries ||= 0
          yield(retries)
        rescue StandardError => e
          sleep(delay + (retries**2) * delay)
          if (retries += 1) < count
            retry
          else
            raise if klass.nil?
            return nil if klass == :skip

            raise klass.new(e.message)
          end
        end
      end

  end

end

