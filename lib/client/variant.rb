module BigcommerceProductAgent
    module Client
        class Variant < AbstractClient
            @uri_base = 'catalog/variants'

            def update(payload)
                raise "this endpoint only has upsert available"
            end

            def create(payload)
                raise "this endpoint only has upsert available"
            end

            def upsert(payload)
                begin
                    response = client.put(uri, payload.to_json)
                    return response.body['data']
                rescue Faraday::Error::ClientError => e
                    puts e.inspect
                    raise e
                end
            end

            def get_by_skus(skus, include = %w[custom_fields modifiers])
                variants = index({
                    'sku:in': skus.join(','),
                    include: include.join(','),
                })

                map = {}

                variants.each do |variant|
                    map[variant['sku']] = variant
                end

                map
            end

        end
    end
end
