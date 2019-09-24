RSpec.configure do |config|
  config.before(:suite) do
    Lusnoc.configure do |c|
      c.logger.level = Logger::WARN
    end
  end
end

