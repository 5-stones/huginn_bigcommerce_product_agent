module BigcommerceProductAgent
    module Client
        class Product < AbstractClient
            @uri_base = 'catalog/products/:product_id'

            def update(id, payload, params={})
                begin
                    response = client.put(uri(product_id: id), payload.to_json) do |request|
                        request.params.update(params) if params
                    end
                rescue Faraday::Error::ClientError => e
                    raise e, "\n#{e.message}\nFailed to update product with payload = #{payload.to_json}\n", e.backtrace
                end

                return response.body['data']
            end

            def delete(id)
                response = client.delete(uri(product_id: id))
                return true
            end

            def create(payload, params={})
                begin
                    response = client.post(uri, payload.to_json) do |request|
                        request.params.update(params) if params
                    end
                rescue Faraday::Error::ClientError => e
                    raise e, "\n#{e.message}\nFailed to create product with payload = #{payload.to_json}\n", e.backtrace
                end

                return response.body['data']
            end

            def upsert(payload, params={})
                payload['id'] = payload.delete(:id) unless payload[:id].nil?
                if payload['id']
                    return update(payload['id'], payload, params)
                else
                    return create(payload, params)
                end
            end

            def get_by_sku(sku, include = %w[custom_fields modifiers])
                product = index({
                    'sku': sku,
                    include: include.join(','),
                })

                return product[0]
            end

            def disable(productId)
              upsert({ id: productId, is_visible: false })
            end

            def enable(productId)
              upsert({ id: productId, is_visible: true })
            end
        end
    end
end
