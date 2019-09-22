module Lusnoc
  module Helper

    def logger
      Lusnoc.configuration.logger
    end

    def build_url(path)
      Lusnoc.configuration.url + path
    end

  end
end

