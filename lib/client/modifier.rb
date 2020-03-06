module BigcommerceProductAgent
    module Client
        class Modifier < AbstractClient
            @uri_base = 'catalog/products/:product_id/modifiers/:modifier_id'

            def delete(product_id, modifier_id)
                client.delete(uri(product_id: product_id, modifier_id: modifier_id))
            end

            def upsert(product_id, modifier)
                begin
                    if modifier[:id] || modifier['id']
                        modifier['id'] = modifier[:id] unless modifier[:id].nil?
                        return update(product_id, modifier)
                    else
                        return create(product_id, modifier)
                    end
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def update(product_id, modifier)
                response = client.put(uri(product_id: product_id, modifier_id: modifier['id']), modifier.to_json)
                return response.body['data']
            end

            def create(product_id, modifier)
                response = client.post(uri(product_id: product_id), modifier.to_json)
                return response.body['data']
            end
        end
    end
end
