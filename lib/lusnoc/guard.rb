require 'timeouter'
require 'lusnoc/helper'

module Lusnoc
  class Guard

    include Helper

    attr_reader :callbacks

    def initialize(base_url)
      @base_url = base_url
      @callbacks = {}
      yield(self) if block_given?
    end

    def condition(&block)
      @callbacks[:condition] = block
      self
    end

    def then(&block)
      @callbacks[:then] = block
      self
    end

    def run
      th = start_thread
      yield
    ensure
      th.kill rescue nil
    end

    private

      def start_thread
        Thread.new do
          logger.info "Guard[#{@base_url.inspect}] thread started"
          watch_forever(@base_url)
          fire!
        rescue StandardError => e
          logger.error "Guard[#{@base_url.inspect}] error: #{e.inspect}"
          logger.error e.backtrace
          fire!(e)
        ensure
          logger.info "Guard[#{@base_url.inspect}] finihsed"
        end
      end

      def fire!(*args)
        @callbacks[:then]&.tap do |cb|
          @callbacks[:then] = nil
          logger.info "Guard[#{@base_url.inspect}] fired"
          cb.call(*args)
        end
      end

      def watch_forever(base_url)
        Lusnoc::Watcher.new(base_url).run(max_consul_wait: 10) do |body|
          return true unless @callbacks[:condition].call(body)
        end
      end

      # def watch_forever(base_url)
      #   last_x_consul_index = 1

      #   Kernel.loop do
      #     resp = Lusnoc.http_get("#{base_url}?index=#{last_x_consul_index}&wait=10s", timeout: 15)
      #     logger.debug "Guard[#{@base_url.inspect}] response: #{resp.body}"
      #     return unless @callbacks[:condition].call(resp.body)

      #     index = [Integer(resp['x-consul-index']), 1].max
      #     last_x_consul_index = (index < last_x_consul_index ? 1 : index)
      #     sleep 0.4
      #   end
      # end

  end
end

