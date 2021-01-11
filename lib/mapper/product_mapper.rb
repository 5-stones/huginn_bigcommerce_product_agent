module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map_payload(product, additional_data = {}, is_digital = false, default_sku='')
                name = product['name']

                result = {
                    name: name,
                    sku: product ? product['sku'] : default_sku,
                    is_default: product['isDefault'],
                    type: product['isDigital'] == true || is_digital ? 'digital' : 'physical',
                    description: product['description'] || '',
                    price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                    categories: self.get_categories(product),
                    availability: self.get_availability(product),
                    weight: product['weight'] ? product['weight']['value'] : '0',
                    width: product['width'] ? product['width']['value'] : '0',
                    depth: product['depth'] ? product['depth']['value'] : '0',
                    height: product['height'] ? product['height']['value'] : '0',
                    meta_keywords: self.meta_keywords(product),
                    meta_description: self.meta_description(product) || '',
                    search_keywords: self.get_search_keywords(additional_data.delete(:additional_search_terms), product),
                    is_visible: true,
                    preorder_release_date: product['releaseDate'] && product['releaseDate'].to_datetime ? product['releaseDate'].to_datetime.strftime("%FT%T%:z") : nil,
                    preorder_message: self.get_availability(product) == 'preorder' ? product['availability'] : '',
                    is_preorder_only: self.get_availability(product) == 'preorder' ? true : false,
                    page_title: product['page_title'] || '',
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
                payload = self.map(product, additional_data, is_digital, sku)
                payload[:id] = product_id unless product_id.nil?
                payload[:sku] = sku

                return payload
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

            # get a list of search keywords for the products
            def self.get_search_keywords(additional_search_terms, product)
                return (self.meta_keywords(product) + additional_search_terms.split(",")).join(",")
            end

            def self.get_availability(product)
                if product['datePublished'] && product['datePublished'].to_datetime && product['datePublished'].to_datetime < DateTime.now
                    return 'available'
                else
                    if product['releaseDate'] && product['releaseDate'].to_datetime
                        if product['releaseDate'].to_datetime > DateTime.now
                            return 'preorder'
                        else
                            return 'available'
                        end
                    else
                        return 'disabled'
                    end
                end
            end

            def self.get_availability_offer(product)
                if product['offers'] && product['offers'][0]
                    return product['offers'][0]['availability']
                return ''
            end
        end
    end
end
