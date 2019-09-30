$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'lusnoc/version'

Gem::Specification.new 'lusnoc' do |spec|
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{Lusnoc::VERSION}.#{ENV['BUILDVERSION'].to_i}" : Lusnoc::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']
  spec.description   = spec.summary = 'Lusnoc is reliable gem to deal with consul'
  spec.homepage      = 'https://github.com/RnD-Soft/lusnoc'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/lusnoc.rb lib/lusnoc README.md LICENSE features`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
  spec.add_development_dependency 'webmock'

  spec.add_runtime_dependency 'json'
  spec.add_runtime_dependency 'timeouter'
end

