module BigcommerceProductAgent
    module Client
        class ProductVariant < AbstractClient
            @uri_base = 'catalog/products/:product_id/variants/:variant_id'

            def index(product_id, params = {})
                response = client.get(uri(product_id: product_id), params)
                return response.body['data']
            end

            def delete(product_id, variant_id)
                client.delete(uri(product_id: product_id, variant_id: variant_id))
            end

            def upsert(product_id, variant)
                begin
                    if variant[:id] || variant['id']
                        variant['id'] = variant[:id] unless variant[:id].nil?
                        return update(product_id, variant)
                    else
                        return create(product_id, variant)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def update(product_id, variant)
                response = client.put(uri(product_id: product_id, variant_id: variant['id']), variant.to_json)
                return response.body['data']
            end

            def create(product_id, variant)
                response = client.post(uri(product_id: product_id), variant.to_json)
                return response.body['data']
            end
        end
    end
end
