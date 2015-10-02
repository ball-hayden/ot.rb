# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ot/version'

Gem::Specification.new do |spec|
  spec.name          = 'ot'
  spec.version       = OT::VERSION
  spec.authors       = ['Hayden Ball']
  spec.email         = ['hayden@haydenball.me.uk']

  spec.summary       = 'A Ruby port of the ot.js Operational Transformation library'
  spec.homepage      = 'https://github.com/ball-hayden/ot.rb'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
