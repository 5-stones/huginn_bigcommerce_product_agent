module BigcommerceProductAgent
    module Client
        class ProductOptionValue < AbstractClient
            @uri_base = 'catalog/products/:product_id/options/:option_id/values/:value_id'

            def delete(product_id, option_id, value_id)
                client.delete(uri(product_id: product_id, option_id: option_id, value_id: value_id))
            end

            def delete_all(option, option_values)
                option_values.each do |option_value|
                    delete(option['product_id'], option['id'], option_value['id'])
                end
            end

            def upsert(option, option_value)
                begin
                    if option[:product_id] || option['product_id']
                        option['product_id'] = option[:product_id] unless option[:product_id].nil?
                    end

                    if option[:id] || option['id']
                        option['id'] = option[:id] unless option[:id].nil?
                    end

                    if option_value[:id] || option_value['id']
                        option_value['id'] = option_value[:id] unless option_value[:id].nil?
                        return update(option, option_value)
                    else
                        return create(option, option_value)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def upsert_all(option, option_values)
                results = []
                option_values.each do |option_value|
                    result = upsert(option, option_value)
                    results.push(result)
                end

                return results
            end

            def update(option, option_value)
                response = client.put(
                    uri(
                        product_id: option['product_id'],
                        option_id: option['id'],
                        value_id: option_value['id'],
                    ),
                    option_value.to_json,
                )
                return response.body['data']
            end

            def create(option, option_value)
                response = client.post(
                    uri(
                        product_id: option['product_id'],
                        option_id: option['id'],
                    ),
                    option_value.to_json,
                )
                return response.body['data']
            end
        end
    end
end
