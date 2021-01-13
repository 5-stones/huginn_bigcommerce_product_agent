module BigcommerceProductAgent
    module Mapper
        class MetaFieldMapper

            def self.map(field_map, acumen_product, bc_product, meta_fields, namespace)
                fields = {
                    upsert: [],
                    delete: [],
                }

                existing_fields = {}

                if bc_product
                    meta_fields.each do |mf|
                      mf['product_id'] = bc_product['id']
                        unless mf['namespace'] != namespace
                          # Only delete meta fields managed by this sync
                          existing_fields[mf['key'].to_s] = mf
                        end
                    end
                end

                if field_map && field_map['additionalProperty']
                    field_map['additionalProperty'].each do |key, val|
                        field = self.from_additional_property(acumen_product, existing_fields, key, val, namespace, bc_product)
                        fields[:upsert].push(field) unless field.nil?
                    end
                end

                if field_map
                    field_map.each do |key, val|
                        if key == 'additionalProperty'
                            next
                        end

                        field = self.from_property(acumen_product, existing_fields, key, val, namespace, bc_product)
                        fields[:upsert].push(field) unless field.nil?
                    end
                end

                # return values that need deleted
                fields[:delete] = existing_fields.values
                return fields
            end

            private

            def self.from_property(acumen_product, existing_fields, from_key, to_key, namespace, bc_product)

                if !acumen_product[from_key].nil?
                    field = {
                        namespace: namespace,
                        permission_set: 'write',
                        resource_type: 'acumen_product',
                        key: to_key,
                        value: acumen_product[from_key]
                    }

                    if bc_product
                      field[:resource_id] = bc_product['id']
                    end

                    if existing_fields[to_key]
                        field[:id] = existing_fields[to_key]['id']
                        existing_fields.delete(to_key)
                    end

                    return field
                end
            end

            def self.from_additional_property(acumen_product, existing_fields, from_key, to_key, namespace, bc_product)

                item = acumen_product['additionalProperty'].select {|p| p['propertyID'] == from_key}.first
                if !item.nil?

                    field = {
                        namespace: namespace,
                        permission_set: 'write',
                        resource_type: 'acumen_product',
                        key: to_key,
                        value: item['value']
                    }

                    if bc_product
                      field[:resource_id] = bc_product['id']
                    end

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
