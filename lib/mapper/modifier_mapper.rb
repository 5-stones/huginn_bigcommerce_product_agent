module BigcommerceProductAgent
    module Mapper
        class ModifierMapper

            def self.map(bc_product, bc_children, sku_option_map, is_default_map)
                modifier = {
                    display_name: 'Option',
                    type: 'product_list',
                    required: true,
                    sort_order: 1,
                    config: {
                        product_list_adjusts_inventory: true,
                        product_list_adjusts_pricing: true,
                        product_list_shipping_calc: 'none'
                    },
                    option_values: []
                }

                existing_modifier = nil
                existing_option_ids = []
                if bc_product && !bc_product['modifiers'].nil?
                    existing_modifier = bc_product['modifiers'].select {|m| m['display_name'] == modifier[:display_name]}.first
                    modifier[:product_id] = bc_product['id']

                    if !existing_modifier.nil?
                        modifier[:id] = existing_modifier['id']
                        existing_option_ids = existing_modifier['option_values'].map {|value| value['id']}
                    end
                end

                bc_children.each do |child|
                    existing_option = nil
                    if existing_modifier
                        existing_option = existing_modifier['option_values'].select do |val|
                            val['value_data'] && val['value_data']['product_id'] == child['id']
                        end.first
                    end

                    option = {
                        label: sku_option_map[child['sku']],
                        sort_order: 0,
                        value_data: {
                            product_id: child['id']
                        },
                        is_default: is_default_map[child['sku']],
                        adjusters: {
                            price: nil,
                            weight: nil,
                            image_url: '',
                            purchasing_disabled: {
                                status: false,
                                message: ''
                            }
                        }
                    }

                    if existing_option
                        option[:id] = existing_option['id']
                        option[:option_id] = existing_option['option_id']
                        existing_option_ids.delete(existing_option['id'])
                    end

                    modifier[:option_values].push(option)
                end

                # any left over option value should be removed
                modifier_values_delete = existing_option_ids.map do |id|
                    {
                        product_id: bc_product['id'],
                        modifier_id: existing_modifier['id'],
                        value_id: id
                    }
                end

                return {
                    upsert: modifier,
                    delete: modifier_values_delete
                }
            end

        end
    end
end
