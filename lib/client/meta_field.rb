module BigcommerceProductAgent
    module Client
        class MetaField < AbstractClient
            @uri_base = 'catalog/products/:product_id/metafields/:meta_field_id'

            def get_for_product(product_id)
              return [] if product_id.blank?

              response = client.get(uri(product_id: product_id))
              return response.body['data']
            end

            def create(product_id, meta_field)
              response = client.post(
                uri(product_id: product_id),
                meta_field.to_json
              )

              return response.body['data']
            end

            def update(product_id, meta_field)
              response = client.put(
                uri(product_id: product_id, meta_field_id: meta_field['id']),
                meta_field.to_json
              )

              return response.body['data']
            end

            def upsert(product_id, meta_field)
              meta_field['id'] = meta_field.delete(:id) unless meta_field[:id].nil?
              begin
                if meta_field['id']
                  return update(product_id, meta_field)
                else
                  return create(product_id, meta_field)
                end
              rescue Faraday::Error::ClientError => e
                puts e.inspect
                raise e
              end
            end

            def delete(product_id, meta_field_id)
                begin
                    client.delete(uri(product_id: product_id, meta_field_id: meta_field_id))
                rescue Faraday::Error::ClientError => e
                    raise e, "\n#{e.message}\nFailed to delete meta_field with id = #{meta_field_id}\nfor product with id = #{product_id}\n", e.backtrace
                end
            end
        end
    end
end
