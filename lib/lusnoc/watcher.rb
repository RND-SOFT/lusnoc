require 'lusnoc/timeouter'
require 'lusnoc/helper'

module Lusnoc
  class Watcher

    include Helper

    def initialize(base_url,
                   timeout: 0,
                   exception_class: TimeoutError,
                   exception_message: 'watch timeout')
      @base_url = base_url
      @timeout = timeout
      @exception_class = exception_class
      @exception_message = exception_message
    end

    # run Consul blocking request in a loop with timeout support.
    # break condition yielded by block call with response body
    def run
      logger.debug "Watch #{@base_url} with #{@timeout.inspect} timeout"
      last_x_consul_index = 1

      Timeouter.new(@timeout,
                    exception_class:   @exception_class,
                    exception_message: @exception_message).loop! do |timeouter|
        wait_condition = timeouter.left ? "&wait=#{timeouter.left.to_i}s" : ''
        url = "#{@base_url}?index=#{last_x_consul_index}#{wait_condition}"

        resp = Lusnoc.http_get(url, timeout: timeouter.left)
        return true if yield(resp.body)

        logger.debug "Watch #{@base_url} response: #{resp.body}"

        index = [Integer(resp['x-consul-index']), 1].max
        last_x_consul_index = (index < last_x_consul_index ? 1 : index)
        sleep 1
      end
    end

  end
end

