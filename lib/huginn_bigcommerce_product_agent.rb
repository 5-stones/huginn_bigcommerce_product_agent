require 'huginn_agent'
require 'json'

# load clients
HuginnAgent.load 'abstract_client'
Dir[File.join(__dir__, 'client', '*.rb')].each do |file|
    HuginnAgent.load file
end

# load mappers
Dir[File.join(__dir__, 'mapper', '*.rb')].each do |file|
    HuginnAgent.load file
end

HuginnAgent.register 'huginn_bigcommerce_product_agent/bigcommerce_product_agent'
