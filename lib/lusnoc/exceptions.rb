require 'timeout'

module Lusnoc

  class Error < RuntimeError; end

  class TimeoutError < Error; end

  class ExpiredError < Error; end

end

