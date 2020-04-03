module BigcommerceProductAgent
    module Client
        class ProductOption < AbstractClient
            @uri_base = 'catalog/products/:product_id/options/:option_id'

            def delete(product_id, option_id)
                client.delete(uri(product_id: product_id, option_id: option_id))
            end

            def delete_all(options)
                options.each do |option|
                    delete(option['product_id'], option['id'])
                end
            end

            def upsert(product_id, option)
                begin
                    if option[:id] || option['id']
                        option['id'] = option[:id] unless option[:id].nil?
                        return update(product_id, option)
                    else
                        return create(product_id, option)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def update(product_id, option)
                response = client.put(uri(product_id: product_id, option_id: option['id']), option.to_json)
                return response.body['data']
            end

            def create(product_id, option)
                response = client.post(uri(product_id: product_id), option.to_json)
                return response.body['data']
            end
        end
    end
end
