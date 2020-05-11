module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map(product, variant, additional_data = {}, is_digital = false, default_sku='')
                name = product['name']

                if variant
                    # variants inherit from and override parent product info
                    name = "#{name} (#{self.get_option(variant)})"
                    product = product.merge(variant)
                else
                    # wrapper product
                    default_variant = self.get_variant_by_sku(product['sku'], product)
                    if default_variant
                        # pull up some properties from default variant (since bc doesn't display them otherwise)
                        product = {
                            "weight" => default_variant['weight'],
                            "width" => default_variant['width'],
                            "depth" => default_variant['depth'],
                            "height" => default_variant['height'],
                        }.merge(product)
                    end
                end

                result = {
                    name: name,
                    sku: product ? product['sku'] : default_sku,
                    is_default: product['isDefault'],
                    type: product['isDigital'] == true || is_digital ? 'digital' : 'physical',
                    description: product['description'],
                    price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                    categories: self.get_categories(product),
                    available: 'available',
                    weight: product['weight'] ? product['weight']['value'] : '0',
                    width: product['width'] ? product['width']['value'] : '0',
                    depth: product['depth'] ? product['depth']['value'] : '0',
                    height: product['height'] ? product['height']['value'] : '0',
                    meta_keywords: self.meta_keywords(product),
                    meta_description: self.meta_description(product),
                    search_keywords: self.meta_keywords(product).join(','),
                    is_visible: variant ? false : true,
                }
                result[:upc] = product['gtin12'] if product['gtin12']

                result.merge(additional_data)
            end

            def self.get_wrapper_sku(product)
                if product
                    "#{product['sku']}-W"
                end
            end

            def self.payload(sku, product, product_id = nil, additional_data = {}, is_digital = false)
                variant = self.get_variant_by_sku(sku, product)
                payload = self.map(product, variant, additional_data, is_digital, sku)
                payload[:id] = product_id unless product_id.nil?
                payload[:sku] = self.get_wrapper_sku(product)

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
                    clone['sku'] = clone['model'].select {|m| m['isDefault'] = true}.first['sku']
                    self.merge_additional_properties(clone, field_map)
                    result[:digital] = clone
                end

                physicals = product['model'].select {|m| m['isDigital'] != true}

                if physicals.length > 0
                    clone = Marshal.load(Marshal.dump(product))
                    clone['model'] = physicals
                    clone['sku'] = clone['model'].select {|m| m['isDefault'] = true}.first['sku']
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
