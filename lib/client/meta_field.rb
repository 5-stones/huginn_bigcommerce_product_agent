module BigcommerceProductAgent
    module Client
        class MetaField < AbstractClient
            @uri_base = 'catalog/products/:product_id/metafields/:meta_field_id'

            def get_for_product(product_id)
              return [] if product_id.blank?

              response = client.get(uri(product_id: product_id))
              return response.body['data']
            end

            def create(meta_field)
              response = client.post(
                uri(product_id: meta_field[:resource_id]),
                meta_field.to_json
              )

              return response.body['data']
            end

            def update(meta_field)
              response = client.put(
                uri(product_id: meta_field[:resource_id], meta_field_id: meta_field[:id]),
                meta_field.to_json
              )

              return response.body['data']
            end

            def upsert(meta_field)
              begin
                if meta_field[:id]
                  return update(meta_field)
                else
                  return create(meta_field)
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
