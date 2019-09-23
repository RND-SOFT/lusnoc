require 'socket'
require 'lusnoc/session'

module Lusnoc
  class Mutex

    include Helper
    attr_reader :key, :value, :owner

    def initialize(key, value: Socket.gethostname, ttl: 20)
      @key = key
      @value = value
      @ttl = ttl
    end

    def locked?
      !!owner
    end

    def owned?
      owner == Thread.current
    end

    def session_id
      @session&.id
    end

    [:time_to_expiration, :need_renew?, :ttl, :expired?, :alive?, :alive!, :renew].each do |m|
      define_method(m) { @session&.public_send(m) }
    end

    def on_mutex_lost(&block)
      @on_mutex_lost = block
    end

    def synchronize(timeout: 0, &block)
      t = Timeouter::Timer.new(timeout, eclass: TimeoutError, message: 'mutex acquisition expired')

      Session.new("mutex_session/#{key}", ttl: @ttl) do |session|
        @session = session
        session.on_session_die do
          @owner = nil
          @on_mutex_lost&.call(self)
        end

        return acquisition_loop! key, session, value, t, &block
      ensure
        release(key, session.id, timeout: 2) rescue nil
        logger.info("Lock #{key} released for session #{session.name}[#{session.id}]")
        @owner = nil
        @session = nil
      end
    end

    private

      def acquire(key, session, value)
        resp = Lusnoc.http_put(build_url("/v1/kv/#{key}?acquire=#{session.id}"), value, timeout: 1)
        return false if resp.body.chomp != 'true'

        @owner = Thread.current
        logger.info("Lock #{key} acquired for session #{session.name}[#{session.id}]")
        renew
        true
      end

      def release(key, session)
        Lusnoc.http_put(build_url("/v1/kv/#{key}?release=#{session.id}"), timeout: 1)
      end

      def acquisition_loop!(key, session, value, t)
        return yield(self) if acquire(key, session, value)

        logger.debug("Start #{key} acquisition loop for session #{session.name}[#{session.id}]")
        t.loop! do
          session.alive!(TimeoutError)
          wait_for_key_released(key, t.left)

          return yield(self) if acquire(key, session, value)

          logger.debug("Lock #{key} acquisition failed for session #{session.name}[#{session.id}]")
          sleep 1
        end
      end

      def wait_for_key_released(key, timeout = nil)
        logger.debug "Waiting for key #{key} to be fre of any session"
        Lusnoc::Watcher.new(build_url("/v1/kv/#{key}"),
                            timeout:  timeout,
                            eclass:   TimeoutError,
                            emessage: 'mutex acquisition expired').run do |body|
          result = JSON.parse(body.empty? ? '[{}]' : body)
          return true if result.first['Session'].nil?
        end
      end

  end
end

