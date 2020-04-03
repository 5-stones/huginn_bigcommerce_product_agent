module BigcommerceProductAgent
    module Mapper
        class OptionMapper

            def self.variant_option_name
                'Options'
            end

            def self.map(product_id, option, option_values)
                mapped = {
                    product_id: product_id,
                    display_name: self.variant_option_name,
                    type: 'radio_buttons',
                    sort_order: 0,
                    option_values: option_values,
                }

                if option && option['id']
                    mapped[:id] = option['id']
                end

                return mapped
            end

            def self.option_value_operations(bc_option, option_values)
                option_value_operations = {
                    create: [],
                    update: [],
                    delete: [],
                }

                if bc_option && bc_option['option_values']
                    bc_option['option_values'].each do |option_value|
                        if option_values.include?(option_value['label'])
                            option_value_operations[:update].push(option_value)
                        else
                            option_value_operations[:delete].push(option_value)
                        end
                    end

                    option_values.each do |option_value_label|
                        options_exists = bc_option['option_values'].any? {|option_value| option_value['label'] == option_value_label}
                        if !options_exists
                            option_value_operations[:create].push(
                                OptionValueMapper.map(option_value_label)
                            )
                        end
                    end
                else
                    option_values.each do |option_value_label|
                        option_value_operations[:create].push(
                            OptionValueMapper.map(option_value_label)
                        )
                    end
                end

                return option_value_operations
            end

            private


        end
    end
end
