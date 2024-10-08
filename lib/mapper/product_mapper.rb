module BigcommerceProductAgent
    module Mapper
        class ProductMapper

            def self.map_payload(product, bc_product, additional_data = {}, track_inventory = true, default_sku = '')
                name = product['name']
                isDigital = product['isDigital'].to_s == 'true'

                track_inventory = self.get_availability(product) == 'preorder' ? false : track_inventory

                # respect the visibility setting of existing products, otherwise
                # default visibility to true.
                is_visible = true
                if !bc_product.nil? && !bc_product['is_visible'].nil?
                  is_visible = bc_product['is_visible']
                end

                result = {
                  availability: self.get_availability(product),
                  categories: self.get_categories(product),
                  depth: product['depth'] ? product['depth']['value'] : '0',
                  description: product['description'] || '',
                  height: product['height'] ? product['height']['value'] : '0',
                  is_default: product['isDefault'],
                  is_preorder_only: false,
                  is_visible: is_visible,
                  meta_description: self.meta_description(product) || '',
                  meta_keywords: self.meta_keywords(product),
                  name: name,
                  page_title: product['page_title'] || '',
                  preorder_message: self.get_availability(product) == 'preorder' ? product['offers'][0]['availability'] : '',
                  preorder_release_date: product['releaseDate'] && product['releaseDate'].to_datetime ? product['releaseDate'].to_datetime.strftime("%FT%T%:z") : nil,
                  price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                  retail_price: product['offers'] && product['offers'][0] ? product['offers'][0]['price'] : '0',
                  search_keywords: self.get_search_keywords(additional_data.delete(:additional_search_terms), product),
                  sku: product ? product['sku'] : default_sku,
                  type: isDigital ? 'digital' : 'physical',
                  weight: product['weight'] ? product['weight']['value'] : '0',
                  width: product['width'] ? product['width']['value'] : '0',
                }

                #  BEGIN:  The following block is a workaround for a BigCommerce bug.
                #
                #  It seems that when the `inventory_tracking` attribute is included in the payload,
                #  BigCommerce is now triggering a low stock warning for products with inventory
                #  tracking disabled.
                #
                #  We are currently seeing notifications for _every digital product_ each time
                #  the sync process runs.
                #
                #  Pending a fix from BigCommerce the following logic is designed to mitigate
                #  the false alarms. Essentially, we will only be including the `inventory_tracking`
                #  attribute if the value is _changing_ from whatever is currently set.
                #  While this may not stop _all_ of the false alarms, it should reduce them
                #  significantly.
                current_tracking_value = bc_product['inventory_tracking'] unless bc_product.nil?
                new_tracking_value = isDigital || !track_inventory ? 'none' : 'product'

                if (current_tracking_value != new_tracking_value)
                  result[:inventory_tracking] = new_tracking_value
                end
                #  END:   Stock warning workaround


                stock = get_additional_property_value(product, 'product_inventory', 0)

                if (stock)
                  result[:inventory_level] = stock
                end

                result[:upc] = product['isbn'] ? product['isbn'] : product['gtin12']
                result[:gtin] = product['gtin12'] if product['gtin12']

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
              search_keywords << product['isbn'] if product['isbn'].present?
              if (additional_search_terms && !additional_search_terms.empty?)
                search_keywords.concat(additional_search_terms)
              end

              return search_keywords.uniq.join(",")
            end

            def self.get_availability(product)
                if product['productAvailability'] == 'not available'
                  return 'disabled'
                else
                  return product['productAvailability']
                end
            end
        end
    end
end
