# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'interjectable/version'

Gem::Specification.new do |spec|
  spec.name          = "interjectable"
  spec.version       = Interjectable::VERSION
  spec.authors       = ["Zach Margolis"]
  spec.email         = ["zbmargolis@gmail.com"]
  spec.description   = %q{A simple dependency injection library for unit testing}
  spec.summary       = %q{A simple dependency injection library for unit testing}
  spec.homepage      = "https://github.com/zachmargolis/interjectable"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
end
