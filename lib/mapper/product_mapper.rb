module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map_payload(product, additional_data = {}, track_inventory = true, default_sku = '')
                name = product['name']
                isDigital = product['isDigital'].to_s == 'true'

                result = {
                  availability: self.get_availability(product),
                  categories: self.get_categories(product),
                  depth: product['depth'] ? product['depth']['value'] : '0',
                  description: product['description'] || '',
                  height: product['height'] ? product['height']['value'] : '0',
                  is_default: product['isDefault'],
                  is_preorder_only: self.get_availability(product) == 'preorder' ? true : false,
                  is_visible: true,
                  meta_description: self.meta_description(product) || '',
                  meta_keywords: self.meta_keywords(product),
                  name: name,
                  page_title: product['page_title'] || '',
                  preorder_message: self.get_availability(product) == 'preorder' ? product['availability'] : '',
                  preorder_release_date: product['releaseDate'] && product['releaseDate'].to_datetime ? product['releaseDate'].to_datetime.strftime("%FT%T%:z") : nil,
                  price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                  retail_price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                  search_keywords: self.get_search_keywords(additional_data.delete(:additional_search_terms), product),
                  sku: product ? product['sku'] : default_sku,
                  type: isDigital ? 'digital' : 'physical',
                  weight: product['weight'] ? product['weight']['value'] : '0',
                  width: product['width'] ? product['width']['value'] : '0',
                  inventory_tracking: isDigital || !track_inventory ? 'none' : 'product',
                }
                result[:upc] = product['gtin12'] if product['gtin12']

                result.merge(additional_data)
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

                meta_keywords = product['keywords'].split(',') unless product['keywords'].nil?

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
              search_keywords = self.meta_keywords(product)
              if (additional_search_terms && !additional_search_terms.empty?)
                search_keywords.concat(additional_search_terms)
              end

              return search_keywords.uniq.join(",")
            end

            def self.get_availability(product)
                if product['productAvailability'] == 'disabled'
                  return 'disabled'
                end

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
        end
    end
end
