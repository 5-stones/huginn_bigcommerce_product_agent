module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map(product, variant, additional_data = {})
                product = {
                    name: variant.nil? ? product['name'] : "#{product['name']} (#{self.get_option(variant)})",
                    sku: variant ? variant['sku'] : self.get_wrapper_sku(product),
                    type: variant && variant['isDigital'] == true ? 'digital' : 'physical',
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

            def self.payload(sku, product, product_id = nil, additional_data = {})
                variant = self.get_variant_by_sku(sku, product)
                payload = self.map(product, variant, additional_data)
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

        end
    end
end
