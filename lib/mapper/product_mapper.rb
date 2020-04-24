module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map(product, variant, additional_data = {}, is_digital = false, default_sku='')
                product = {
                    name: variant.nil? ? product['name'] : "#{product['name']} (#{self.get_option(variant)})",
                    sku: variant ? variant['sku'] : default_sku,
                    is_default: variant && variant['isDefault'],
                    type: (variant && variant['isDigital'] == true) || is_digital ? 'digital' : 'physical',
                    description: product['description'],
                    price: variant && variant['offers'] && variant['offers'][0] ? variant['offers'][0]['price'] : '0',
                    categories: self.get_categories(product),
                    available: 'available',
                    weight: variant && variant['weight'] ? variant['weight']['value'] : '0',
                    width: variant && variant['width'] ? variant['width']['value'] : '0',
                    depth: variant && variant['depth'] ? variant['depth']['value'] : '0',
                    height: variant && variant['height'] ? variant['height']['value'] : '0',
                    meta_keywords: self.meta_keywords(product),
                    meta_description: self.meta_description(product),
                    search_keywords: self.meta_keywords(product).join(','),
                    is_visible: variant.nil? ? true : false,
                }.merge(additional_data)


                upc = variant ? variant['gtin12'] : product['gtin12']

                if upc
                    product[:upc] = upc
                end

                return product
            end

            def self.get_wrapper_sku(product)
                "#{product['sku']}-W"
            end

            def self.get_wrapper_sku_physical(product)
                self.get_wrapper_sku(product)
            end

            def self.get_wrapper_sku_digital(product)
                "#{self.get_wrapper_sku_physical(product)}-DIGITAL"
            end

            def self.payload(sku, product, product_id = nil, additional_data = {}, is_digital = false)
                variant = self.get_variant_by_sku(sku, product)
                payload = self.map(product, variant, additional_data, is_digital, sku)
                payload['id'] = product_id unless product_id.nil?

                return payload
            end

            def self.get_product_skus(product)
                product['model'].map { |model| model['sku'] }
            end

            def self.get_sku_option_label_map(product)
                map = {}

                product['model'].each do |model|
                    map[model['sku']] = self.get_option(model)
                end

                return map
            end

            def self.get_is_default(product)
              map = {}

              product['model'].each do |model|
                  map[model['sku']] = model["isDefault"]
              end

              return map
            end

            def self.has_digital_variants?(product)
                product['model'].any? {|m| m['isDigital'] == true}
            end

            def self.has_physical_variants?(product)
                product['model'].any? {|m| m['isDigital'] != true}
            end

            def self.split_digital_and_physical(product, field_map)
                result = {}

                digitals = product['model'].select {|m| m['isDigital'] == true}

                if digitals.length > 0
                    clone = Marshal.load(Marshal.dump(product))
                    clone['model'] = digitals
                    self.merge_additional_properties(clone, field_map)
                    result[:digital] = clone
                end

                physicals = product['model'].select {|m| m['isDigital'] != true}

                if physicals.length > 0
                    clone = Marshal.load(Marshal.dump(product))
                    clone['model'] = physicals
                    self.merge_additional_properties(clone, field_map)
                    result[:physical] = clone
                end

                return result
            end

            private

            def self.get_categories(product)
                categories = []

                if product['categories']
                    categories = product['categories'].map do |category|
                        category['identifier'].to_i
                    end
                end

                return categories
            end

            def self.get_option(variant)
                if variant['encodingFormat']
                    return variant['encodingFormat']
                elsif variant['bookFormat']
                    parts = variant['bookFormat'].split('/')
                    return parts[parts.length - 1]
                else
                    return self.get_additional_property_value(variant, 'option')
                end
            end

            def self.meta_description(product)
                return self.get_additional_property_value(product, 'meta_description', '')
            end

            def self.meta_keywords(product)
                meta_keywords = []

                product['keywords'].split(',') unless product['keywords'].nil?

                return meta_keywords
            end

            def self.get_additional_property_value(product, name, default = nil)
                value = default

                return value if product['additionalProperty'].nil?

                idx = product['additionalProperty'].index {|item| item['propertyID'] == name}
                value = product['additionalProperty'][idx]['value'] unless idx.nil?

                return value
            end

            def self.get_variant_by_sku(sku, product)
                product['model'].select {|m| m['sku'] == sku}.first
            end

            def self.merge_additional_properties(clone, field_map)
                defaultVariant = clone['model'].select { |v| v['isDefault'] }.first
                if defaultVariant['isDefault'] && defaultVariant['additionalProperty']
                    unless  field_map.nil? || field_map['additionalProperty'].nil?
                        field_map['additionalProperty'].each do |field, key|
                            prop = defaultVariant['additionalProperty'].select { |prop| prop['propertyID'] == field[key] }.first
                            clone['additionalProperty'].push(prop) unless prop.nil?
                        end
                    end
                end
            end
        end
    end
end
