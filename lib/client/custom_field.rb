module BigcommerceProductAgent
    module Client
        class CustomField < AbstractClient
            @uri_base = 'catalog/products/:product_id/custom-fields/:custom_field_id'

            def delete(product_id, custom_field_id)
                client.delete(uri(product_id: product_id, custom_field_id: custom_field_id))
            end
        end
    end
end
