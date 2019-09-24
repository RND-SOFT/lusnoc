require 'lusnoc/watcher'
require 'lusnoc/guard'

module Lusnoc
  class Session

    include Helper

    attr_reader :id, :name, :ttl, :alive, :expired_at

    def initialize(name, ttl: 20, &block)
      @name = name
      @ttl = ttl

      run(&block) if block_given?
    end

    def run
      @id = create_session(name, ttl)

      prepare_guard(@id).run do
        yield(self)
      end
    ensure
      destroy_session(@id) if @id
    end

    def expired?
      !alive?
    end

    def time_to_expiration
      @expired_at && @expired_at - Time.now
    end

    def need_renew?
      time_to_expiration && time_to_expiration < (@ttl / 2.0)
    end

    def alive?
      @alive
    end

    def alive!(exception_class = ExpiredError)
      @alive || (raise exception_class.new("Session[#{@name}:#{@id}] expired"))
    end

    def renew
      alive!
      Lusnoc.http_put(build_url("/v1/session/renew/#{@id}"), nil, timeout: 1)
      @expired_at = Time.now + ttl
      logger.info "Session[#{@name}:#{@id}] renewed. Next expiration: #{@expired_at}"
    end

    def on_session_die(&block)
      @session_die_cb = block
      @session_die_cb&.call(self) if @alive == false
      self
    end

    private

      def create_session(name, ttl)
        resp = Lusnoc.http_put(build_url('/v1/session/create'),
                               { Name: name, TTL: "#{ttl}s", LockDelay: '5s' },
                               { timeout: 1 })
        session_id = JSON.parse(resp.body)['ID']
        @expired_at = Time.now + ttl
        logger.info "Session[#{name}:#{session_id}] created. TTL:#{ttl}s. Next expiration: #{@expired_at}"
        @alive = true
        session_id
      end

      def prepare_guard(session_id)
        Lusnoc::Guard.new(build_url("/v1/session/info/#{session_id}")) do |guard|
          guard.condition do |body|
            !JSON.parse(body).empty? rescue false
          end

          guard.then do
            @alive = false
            @expired_at = nil
            logger.info "Session[#{@name}:#{session_id}] is gone"
            @session_die_cb&.call(self)
          end
        end
      end

      def destroy_session(session_id)
        @alive = false
        @expired_at = nil
        Lusnoc.http_put(build_url("/v1/session/destroy/#{session_id}"), nil, timeout: 1) rescue nil
        logger.info "Session[#{@name}:#{session_id}] destroyed"
      end

  end
end

