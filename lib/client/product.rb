module BigcommerceProductAgent
    module Client
        class Product < AbstractClient
            @uri_base = 'catalog/products/:product_id'

            def update(id, payload, params={})
                response = client.put(uri(product_id: id), payload.to_json) do |request|
                    request.params.update(params) if params
                end

                return response.body['data']
            end

            def delete(id)
                response = client.delete(uri(product_id: id))
                return true
            end

            def create(payload, params={})
                response = client.post(uri, payload.to_json) do |request|
                    request.params.update(params) if params
                end

                return response.body['data']
            end

            def upsert(payload, params={})
                begin
                    if payload[:id]
                        return update(payload[:id], payload, params)
                    else
                        return create(payload, params)
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
