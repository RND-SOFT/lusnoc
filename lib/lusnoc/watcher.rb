require 'timeouter'
require 'lusnoc/exceptions'
require 'lusnoc/helper'

module Lusnoc
  class Watcher

    include Helper

    def initialize(base_url,
                   timeout: 0,
                   eclass: Lusnoc::TimeoutError,
                   emessage: 'watch timeout')
      @base_url = base_url
      @timeout = timeout
      @eclass = eclass
      @emessage = emessage
    end

    # run Consul blocking request in a loop with timeout support.
    # break condition yielded by block call with response body
    def run
      logger.debug "Watch #{@base_url} with #{@timeout.inspect} timeout"
      last_x_consul_index = 1

      Timeouter.loop!(@timeout, eclass: @eclass, message: @emessage) do |t|
        wait_condition = t.left ? "&wait=#{t.left.to_i}s" : ''
        url = "#{@base_url}?index=#{last_x_consul_index}#{wait_condition}"

        resp = Lusnoc.http_get(url, timeout: t.left)
        return true if yield(resp.body)

        logger.debug "Watch #{@base_url} response: #{resp.body}"

        index = [Integer(resp['x-consul-index']), 1].max
        last_x_consul_index = (index < last_x_consul_index ? 1 : index)
        sleep 1
      end
    end

  end
end

