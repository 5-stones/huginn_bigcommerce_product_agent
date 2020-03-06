module BigcommerceProductAgent
    module Mapper
        class CustomFieldMapper

            def self.map(field_map, product, bc_product)
                fields = {
                    upsert: [],
                    delete: [],
                }

                existing_fields = {}

                if bc_product
                    bc_product['custom_fields'].each do |cf|
                        cf['product_id'] = bc_product['id']
                        existing_fields[cf['name'].to_s] = cf
                    end
                end

                if field_map && field_map['additionalProperty']
                    field_map['additionalProperty'].each do |key, val|
                        field = self.from_additional_property(product, existing_fields, key, val)
                        fields[:upsert].push(field) unless field.nil?
                    end
                end

                if field_map
                    field_map.each do |key, val|
                        if key == 'additionalProperty'
                            next
                        end

                        field = self.from_property(product, existing_fields, key, val)
                        fields[:upsert].push(field) unless field.nil?
                    end
                end

                # return values that need deleted
                fields[:delete] = existing_fields.values
                return fields
            end

            private

            def self.from_property(product, existing_fields, from_key, to_key)
                if !product[from_key].nil?
                    field = {
                        name: to_key,
                        value: product[from_key]
                    }

                    if existing_fields[to_key]
                        field[:id] = existing_fields[to_key]['id']
                        existing_fields.delete(to_key)
                    end

                    return field
                end
            end

            def self.from_additional_property(product, existing_fields, from_key, to_key)
                # date published
                item = product['additionalProperty'].select {|p| p['propertyID'] == from_key}.first
                if !item.nil?
                    field = {
                        name: to_key,
                        value: item['value']
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
