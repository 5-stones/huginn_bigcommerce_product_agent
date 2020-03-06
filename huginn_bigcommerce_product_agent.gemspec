# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "huginn_bigcommerce_product_agent"
  spec.version       = "0.0.0"
  spec.authors       = ["Jacob Spizziri"]
  spec.email         = ["jspizziri@weare5stones.com"]

  spec.summary       = %q{Agent that takes a generic product interface and upserts that product in BigCommerce.}
  spec.description   = %q{Agent that takes a generic product interface and upserts that product in BigCommerce.}

  spec.homepage      = "https://github.com/5-stones/huginn_bigcommerce_product_agent"


  spec.files         = Dir['LICENSE.txt', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = Dir['spec/**/*.rb'].reject { |f| f[%r{^spec/huginn}] }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "huginn_agent"
end
