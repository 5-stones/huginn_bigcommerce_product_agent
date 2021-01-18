module BigcommerceProductAgent
    module Mapper
        class CustomFieldMapper

            def self.map(field_map, raw_product, bc_product, current_custom_fields, namespace)
                fields = {
                    upsert: [],
                    delete: [],
                }

                existing_fields = {}

                if bc_product && current_custom_fields
                    current_custom_fields.each do |cf|
                        cf['product_id'] = bc_product['id']
                        existing_fields[cf['name'].to_s] = cf
                    end
                end

                if field_map && field_map['additionalProperty']
                    field_map['additionalProperty'].each do |key, val|
                        field = self.from_additional_property(raw_product, existing_fields, key, val)
                        if field
                          field['product_id'] = bc_product['id']
                          fields[:upsert].push(field)
                        end
                    end
                end

                if field_map
                    field_map.each do |key, val|
                        if key == 'additionalProperty'
                            next
                        end

                        field = self.from_property(raw_product, existing_fields, key, val)
                        if field
                          field['product_id'] = bc_product['id']
                          fields[:upsert].push(field)
                        end
                    end
                end

                # return values that need deleted
                fields[:delete] = existing_fields.values
                return fields
            end

            def self.map_one(bc_product, key, value)
                field = bc_product['custom_fields'].select {|field| key == 'related_product_id'}.first

                mapped = {
                    name: key,
                    value: value.to_s,
                }

                if field
                    mapped[:id] = field['id']
                end

                return mapped
            end

            private

            def self.from_property(raw_product, existing_fields, from_key, to_key)
                if !raw_product[from_key].nil?
                    field = {
                        name: to_key,
                        value: raw_product[from_key].to_s
                    }

                    if existing_fields[to_key]
                        field[:id] = existing_fields[to_key]['id']
                        existing_fields.delete(to_key)
                    end

                    return field
                end
            end

            def self.from_additional_property(raw_product, existing_fields, from_key, to_key)
                # date published
                item = raw_product['additionalProperty'].select {|p| p['propertyID'] == from_key}.first
                if !item.nil?
                    field = {
                        name: to_key,
                        value: item['value'].to_s
                    }

                    if existing_fields[to_key]
                        field[:id] = existing_fields[to_key]['id']
                        existing_fields.delete(to_key)
                    end

                    return field
                end
            end

        end
    end
end
