require './lib/lusnoc/version'

Gem::Specification.new 'lusnoc', Lusnoc::VERSION do |spec|
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']
  spec.description   = spec.summary = 'asd'
  spec.homepage      = 'https://github.com/RnD-Soft/lusnoc'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/lusnoc.rb lib/lusnoc README.md LICENSE features`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'webmock'

  spec.add_runtime_dependency 'json'
  # NOTE not tested on faraday 1.0.0
  # spec.add_runtime_dependency 'faraday', '>= 0.9', '< 1.0.0'
  # spec.add_runtime_dependency 'json_pure' if RUBY_VERSION < '1.9.3'
end

