require 'timeouter'
require 'lusnoc/helper'

module Lusnoc
  class Guard

    include Helper

    def initialize(base_url)
      @base_url = base_url
      yield(self) if block_given?
    end

    def condition(&block)
      @condition = block
      self
    end

    def then(&block)
      @callback = block
      self
    end

    def run
      th = Thread.new do
        logger.info "Guard[#{@base_url.inspect}] thread started"
        watch_forever(@base_url)
        fire!
      rescue StandardError => e
        logger.error "Guard[#{@base_url.inspect}] error: #{e.inspect}"
        fire!
      ensure
        logger.info "Guard[#{@base_url.inspect}] finihsed"
      end

      yield
    ensure
      th.kill rescue nil
    end

    private

      def fire!
        @callback&.tap do |cb|
          @callback = nil
          logger.info "Guard[#{@base_url.inspect}] fired"
          cb.call
        end
      end

      def watch_forever(base_url)
        last_x_consul_index = 1

        Kernel.loop do
          resp = Lusnoc.http_get("#{base_url}?index=#{last_x_consul_index}&wait=10s", timeout: 15)
          logger.debug "Guard[#{@base_url.inspect}] response: #{resp.body}"
          return unless @condition.call(resp.body)

          index = [Integer(resp['x-consul-index']), 1].max
          last_x_consul_index = (index < last_x_consul_index ? 1 : index)
          sleep 1
        end
      end

  end
end

