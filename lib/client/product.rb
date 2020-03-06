module BigcommerceProductAgent
    module Client
        class Product < AbstractClient
            @uri_base = 'catalog/products/:product_id'

            def update(id, payload)
                response = client.put(uri(product_id: id), { data: payload }.to_json)
                return response.body['data']
            end

            def create(payload)
                response = client.post(uri, payload.to_json)
                return response.body['data']
            end

            def upsert(payload)
                begin
                    if payload['id']
                        return update(payload['id'], payload)
                    else
                        return create(payload)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def get_by_skus(skus, include = %w[custom_fields modifiers])
                products = index({
                    'sku:in': skus.join(','),
                    include: include.join(','),
                })

                map = {}

                products.each do |product|
                    map[product['sku']] = product
                end

                map
            end

        end
    end
end
