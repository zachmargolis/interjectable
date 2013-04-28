# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'injectable/version'

Gem::Specification.new do |spec|
  spec.name          = "injectable"
  spec.version       = Injectable::VERSION
  spec.authors       = ["Zach Margolis"]
  spec.email         = ["zbmargolis@gmail.com"]
  spec.description   = %q{A simple dependency injection library for unit testing}
  spec.summary       = %q{A simple dependency injection library for unit testing}
  spec.homepage      = "https://github.com/zachmargolis/injectable"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
