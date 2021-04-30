class BigCommerceProductError < StandardError
  attr_reader :status, :scope, :product_identifier, :data, :original_error

  def initialize(status, scope, message, product_identifier, data, original_error)
    @status = status
    @scope = scope
    @product_identifier = product_identifier
    @data = data
    @original_error = original_error

    super(message)
  end
end
