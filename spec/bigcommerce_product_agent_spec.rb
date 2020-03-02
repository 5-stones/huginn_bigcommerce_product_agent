require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BigcommerceProductAgent do
  before(:each) do
    @valid_options = Agents::BigcommerceProductAgent.new.default_options
    @checker = Agents::BigcommerceProductAgent.new(:name => "BigcommerceProductAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
