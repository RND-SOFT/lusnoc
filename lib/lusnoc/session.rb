require 'lusnoc/watcher'

module Lusnoc
  class Session

    include Helper

    attr_reader :id, :name, :ttl, :live, :expired_at

    def initialize(name, ttl: 20)
      @name = name
      @ttl = ttl

      @id = create_session(name, ttl)
      yield(self)
    ensure
      destroy_session(@id)
    end

    def expired?
      !live?
    end

    def time_to_expiration
      @expired_at && @expired_at - Time.now
    end

    def need_renew?
      time_to_expiration && time_to_expiration < (@ttl / 2.0)
    end

    def live?
      @live
    end

    def live!(exception_class = ExpiredError)
      live? || (raise exception_class.new("Session #{id} expired"))
    end

    def renew
      live!
      Lusnoc.http_put(build_url("/v1/session/renew/#{@id}"), nil, timeout: 1)
      @expired_at = Time.now + ttl
      logger.info "Session renewed: #{name}[#{@id}]. Next expiration: #{@expired_at}"
    end

    def on_session_die(&block)
      @session_die_cb = block
    end

    private

      def create_session(name, ttl)
        resp = Lusnoc.http_put(build_url('/v1/session/create'),
                               { Name: name, TTL: "#{ttl}s", LockDelay: '5s' },
                               { timeout: 1 })
        session_id = JSON.parse(resp.body)['ID']
        @expired_at = Time.now + ttl
        logger.info "Session created: #{name}[#{session_id}]. TTL:#{ttl}s. Next expiration: #{@expired_at}"
        @live = true
        @th = start_watch_thread(session_id)
        session_id
      end

      def destroy_session(session_id)
        @th.kill rescue nil
        Lusnoc.http_put(build_url("/v1/session/destroy/#{session_id}"),
                        nil,
                        timeout: 1) rescue nil
        logger.info "Session destroyed: #{name}[#{session_id}]"
        @live = false
        @expired_at = nil
      end

      def start_watch_thread(session_id)
        Thread.new do
          logger.debug "Guard thread for Session #{name}[#{session_id}] started"

          if wait_forever_for_session_gone(session_id)
            logger.error "Session #{name}[#{session_id}] is gone"
            @live = false
            @expired_at = nil
            @session_die_cb&.call(self)
          else
            logger.unknown 'Something is wrong with thread logic'
          end
        ensure
          logger.debug "Guard thread for Session #{name}[#{session_id}] finihsed"
        end
      end

      def wait_forever_for_session_gone(session_id)
        Lusnoc::Watcher.new(build_url("/v1/session/info/#{session_id}"), timeout: 0).run do |body|
          true if JSON.parse(body).empty?
        end
      rescue StandardError => e
        logger.error "Session #{name}[#{session_id}] watch exception: #{e.inspect}"
        logger.error e.backtrace.join("\n")
        true
      end


  end
end

