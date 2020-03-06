module BigcommerceProductAgent
    module Client
        class ModifierValue < AbstractClient
            @uri_base = 'catalog/products/:product_id/modifiers/:modifier_id/values/:value_id'

            def delete(product_id, modifier_id, value_id)
                client.delete(uri(product_id: product_id, modifier_id: modifier_id, value_id: value_id))
            end
        end
    end
end
