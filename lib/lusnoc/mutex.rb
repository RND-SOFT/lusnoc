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
        logger.info("Mutex[#{key}] released for Session[#{session.name}:#{session.id}]")
        @owner = nil
        @session = nil
      end
    end

    private

      def acquire(key, session, value)
        resp = Lusnoc.http_put(build_url("/v1/kv/#{key}?acquire=#{session.id}"), value, timeout: 1)
        return false if resp.body.chomp != 'true'

        @owner = Thread.current
        logger.info("Mutex[#{key}] acquired for Session[#{session.name}:#{session.id}]")
        renew
        true
      end

      def release(key, session)
        Lusnoc.http_put(build_url("/v1/kv/#{key}?release=#{session.id}"), timeout: 1)
      end

      def acquisition_loop!(key, session, value, t)
        if acquire(key, session, value)
          prepare_guard(session, key).run do
            return yield(self)
          end
        end

        logger.debug("Mutex[#{key}] run acquisition loop for Session[#{session.name}:#{session.id}]")
        t.loop! do
          session.alive!(TimeoutError)
          wait_for_key_released(key, t.left)

          if acquire(key, session, value)
            prepare_guard(session, key).run do
              return yield(self)
            end
          end

          logger.debug("Mutex[#{key}] acquisition failed for Session[#{session.name}:#{session.id}]")
          sleep 0.4
        end
      end

      def prepare_guard(session, key)
        Lusnoc::Guard.new(build_url("/v1/kv/#{key}")) do |guard|
          guard.condition do |body|
            JSON.parse(body).first['Session'] == session.id rescue false
          end

          guard.then do
            @owner = nil
            logger.info("Mutex[#{key}] LOST for Session[#{session.name}:#{session.id}]")
            @on_mutex_lost&.call(self)
          end
        end
      end

      def wait_for_key_released(key, timeout = nil)
        logger.debug("Mutex[#{key}] start waiting of key releasing...")
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

