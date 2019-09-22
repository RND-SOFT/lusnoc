require 'lusnoc/exceptions'

module Lusnoc
  class Timeouter

    attr_reader :exhausted_at, :started_at

    def initialize(timeout = 0,
                   exception_class: TimeoutError,
                   exception_message: 'execution expired')
      timeout ||= 0
      timeout = [timeout, 0].max

      @default_exception_class = exception_class
      @default_exception_message = exception_message

      @started_at = Time.now.to_f
      @exhausted_at = timeout > 0 ? @started_at + timeout : nil
    end

    def self.timeout(timeout = 0)
      self.new(timeout)
    end

    def elapsed
      Time.now.to_f - @started_at
    end

    def left
      @exhausted_at && [@exhausted_at - Time.now.to_f, 0].max
    end

    def check
      !@exhausted_at || (@exhausted_at > Time.now.to_f)
    end

    def check!(exception_class = @default_exception_class)
      check || (raise exception_class.new(@default_exception_message))
    end

    def loop
      yield(self) while self.check
    end

    def loop!(exception_class = @default_exception_class)
      yield(self) while self.check!(exception_class)
    end

  end
end

