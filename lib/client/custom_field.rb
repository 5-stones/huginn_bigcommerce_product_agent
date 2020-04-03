module BigcommerceProductAgent
    module Client
        class CustomField < AbstractClient
            @uri_base = 'catalog/products/:product_id/custom-fields/:custom_field_id'

            def create(product_id, payload)
                response = client.post(uri(product_id: product_id), payload.to_json)
                return response.body['data']
            end

            def update(product_id, payload)
                id = payload.delete('id')
                response = client.put(uri(product_id: product_id, custom_field_id: id), payload.to_json)
                return response.body['data']
            end

            def delete(product_id, custom_field_id)
                client.delete(uri(product_id: product_id, custom_field_id: custom_field_id))
            end

            def upsert(product_id, payload)
                begin
                    payload['id'] = payload.delete(:id) unless payload[:id].nil?
                    if payload['id']
                        return update(product_id, payload)
                    else
                        return create(product_id, payload)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end
        end
    end
end
