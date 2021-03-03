module BigcommerceProductAgent
    module Client
        class Product < AbstractClient
            @uri_base = 'catalog/products/:product_id'

            def update(id, payload, params={})
                begin
                    response = client.put(uri(product_id: id), payload.to_json) do |request|
                        request.params.update(params) if params
                    end

                    return response.body['data']
                rescue Faraday::Error::ClientError => e
                    raise e, "\n#{e.message}\nFailed to update product with payload = #{payload.to_json}\n", e.backtrace
                end
            end

            def update_batch(payload, params={})
              begin
                  response = client.put(uri(), payload.to_json) do |request|
                      request.params.update(params) if params
                  end

                  return response.body['data']
              rescue Faraday::Error::ClientError => e
                  raise e, "\n#{e.message}\nFailed to update product batch with payload = #{payload.to_json}\n", e.backtrace
              end
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

                    return response.body['data']
                rescue Faraday::Error::ClientError => e
                    raise e, "\n#{e.message}\nFailed to create product with payload = #{payload.to_json}\n", e.backtrace
                end
            end

            def upsert(payload, params={})
                payload['id'] = payload.delete(:id) unless payload[:id].nil?
                if payload['id']
                    return update(payload['id'], payload, params)
                else
                    return create(payload, params)
                end
            end

            # When using sku:in you must specify the fields you want returned.
            def get_by_skus(skus, include = %w[custom_fields modifiers], include_fields = %w[sku])
                products = index({
                    'sku:in': skus.join(','),
                    include: include.join(','),
                    include_fields: include_fields.join(','),
                })

                return products
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
