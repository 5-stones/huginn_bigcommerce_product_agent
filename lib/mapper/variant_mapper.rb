module BigcommerceProductAgent
    module Mapper
        class VariantMapper

            def self.map(variant, option_values, product_id, variant_id=nil, not_purchasable_format_list, bc_option_value)
                mapped = {
                    product_id: product_id,
                    sku: variant['sku'],
                    price: variant['offers'] && variant['offers'][0] ? variant['offers'][0]['price'] : '0',
                    cost_price: nil,
                    sale_price: nil,
                    retail_price: nil,
                    weight: variant['weight'] ? variant['weight']['value'] : '0',
                    width: variant['width'] ? variant['width']['value'] : '0',
                    depth: variant['depth'] ? variant['depth']['value'] : '0',
                    height: variant['height'] ? variant['height']['value'] : '0',
                    is_free_shipping: false,
                    fixed_cost_shipping_price: nil,
                    purchasing_disabled: false,
                    purchasing_disabled_message: '',
                    upc: variant['isbn'] ? variant['isbn'] : variant['gtin12'],
                    inventory_level: nil,
                    inventory_warning_level: nil,
                    bin_picking_number: nil,
                    option_values: option_values,
                }

                if variant_id
                    mapped[:id] = variant_id
                end

                not_purchasable_format_list.each do |format|
                    if format == bc_option_value['label']
                        mapped[:purchasing_disabled] = true
                    end
                end

                return mapped
            end

            def self.map_option_value(option_value_id, option_id)
                return {
                    id: option_value_id,
                    option_id: option_id,
                }
            end

            private


        end
    end
end
