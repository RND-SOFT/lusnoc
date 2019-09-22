require 'socket'
require 'lusnoc/session'

module Lusnoc
  class Mutex

    include Helper

    attr_reader :key, :value, :owner

    def initialize(key, value = Socket.gethostname)
      @key = key
      @value = value
    end

    def locked?
      !!owner
    end

    def owned?
      owner == Thread.current
    end

    def synchronize(timeout: 0, &block)
      timeouter = Timeouter.new(timeout,
                                exception_class:   TimeoutError,
                                exception_message: 'mutex acquisition expired')

      Session.new("mutex_session/#{key}") do |session|
        @session = session
        session.on_session_die do
          @owner = nil
        end

        acquisition_loop! key, session, value, timeouter, &block
      ensure
        release(key, session.id, timeout: 2) rescue nil
        @owner = nil
        @session = nil
      end
    end

    def renew
      @session&.renew
    end

    private

      def acquire(key, session, value)
        resp = Lusnoc.http_put(build_url("/v1/kv/#{key}?acquire=#{session.id}"), value, timeout: 1)
        return false if resp.body.chomp != 'true'

        @owner = Thread.current
        logger.debug("Lock #{key} acquired for session #{session.name}[#{session.id}]")
        renew
        true
      end

      def release(key, session)
        Lusnoc.http_put(build_url("/v1/kv/#{key}?release=#{session.id}"), timeout: 1)
      end

      def acquisition_loop!(key, session, value, timeouter)
        return yield(self) if acquire(key, session, value)

        timeouter.loop! do
          session.live!
          wait_for_key_released(key, timeouter.left)

          return yield(self) if acquire(key, session, value)

          logger.debug("Lock Failed #{key} for session #{session.name}[#{session.id}]")
          sleep 1
        end
      end

      def wait_for_key_released(key, timeout = nil)
        logger.debug "Waiting for key #{key} to be fre of any session"
        Lusnoc::Watcher.new(build_url("/v1/kv/#{key}"),
                            timeout:           timeout,
                            exception_class:   TimeoutError,
                            exception_message: 'mutex acquisition expired').run do |body|
          result = JSON.parse(body.empty? ? '[{}]' : body)
          return true if result.first['Session'].nil?
        end
      end

  end
end

