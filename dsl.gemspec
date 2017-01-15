# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dsl/version'

Gem::Specification.new do |spec|
  spec.name          = "dsl"
  spec.version       = Dsl::VERSION
  spec.authors       = ["david karapetyan"]
  spec.email         = ["dkarapetyan@gmail.com"]

  spec.summary       = %q{Tired of gimped DSLs for configuring infrastructure.}
  spec.homepage      = "https://github.com/davidk01/non-gimp"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "pry"

  spec.add_runtime_dependency "aws-sdk", "~> 2"
  spec.add_runtime_dependency "netaddr"
end
