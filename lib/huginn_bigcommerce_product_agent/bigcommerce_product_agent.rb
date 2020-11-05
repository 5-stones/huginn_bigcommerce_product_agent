# frozen_string_literal: true

require 'json'

module Agents
    class BigcommerceProductAgent < Agent
        include WebRequestConcern

        can_dry_run!
        default_schedule 'never'

        description <<-MD
            Takes a generic product interface && upserts that product in BigCommerce.
        MD

        def modes
            %w[
                variants
                option_list
            ]
        end

        def default_options
            {
                'store_hash' => '',
                'client_id' => '',
                'access_token' => '',
                'custom_fields_map' => {},
                'meta_fields_map' => {},
                'meta_fields_namespace' => '',
                'mode' => modes[0],
                'not_purchasable_format_list' => [],
                'should_disambiguate' => false
            }
        end

        def validate_options
            unless options['store_hash'].present?
                errors.add(:base, 'store_hash is a required field')
            end

            unless options['client_id'].present?
                errors.add(:base, 'client_id is a required field')
            end

            unless options['access_token'].present?
                errors.add(:base, 'access_token is a required field')
            end

            unless options['custom_fields_map'].is_a?(Hash)
                errors.add(:base, 'if provided, custom_fields_map must be a hash')
            end

            unless options['meta_fields_map'].is_a?(Hash)
                errors.add(:base, 'if provided, meta_fields_map must be a hash')
            end

            if options['meta_fields_map']
                if options['meta_fields_namespace'].blank?
                    errors.add(:base, 'if meta_fields_map is provided, meta_fields_namespace is required')
                end
            end

            unless options['mode'].present? && modes.include?(options['mode'])
                errors.add(:base, "mode is a required field and must be one of: #{modes.join(', ')}")
            end

            if options['not_purchasable_format_list'].present? && !options['not_purchasable_format_list'].is_a?(Array)
                errors.add(:base, 'not_purchasable_format_list must be an Array')
            end

            if options.has_key?('should_disambiguate') && boolify(options['should_disambiguate']).nil?
                errors.add(:base, 'when provided, `should_disambiguate` must be either true or false')
            end

        end

        def working?
            received_event_without_error?
        end

        def check
            initialize_clients
            handle interpolated['payload'].presence || {}
        end

        def receive(incoming_events)
            initialize_clients
            incoming_events.each do |event|
                handle(event)
            end
        end

        def handle(event)
            method_name = "handle_#{interpolated['mode']}"
            if self.respond_to?(method_name, true)
                self.public_send(method_name, event)
            else
                raise "'#{interpolated['mode']}' is not a supported mode"
            end
        end

        # 1. Upsert the core product (Wrapper Product)
        #     - NOTE: This initial  upsert intentionally disables the product.
        #       Doing so prevents content hiccups with variants particularly
        #       for products going off sale.
        # 2. Upsert option & option_values (BigCommerce Variants)
        # 3. Delete old option_values
        #     - NOTE: deleting an option_value also deletes the variant
        #       associated with the option_value
        # 4. Upsert variants
        #     - NOTE: because deleting option values deletes variants
        #       we need to fetch the variants AFTER deletion has occurred.
        #     - NOTE: by deleting variants in #3 if option_values on an
        #       existing variant changes over time, we're effectively deleting
        #       and then re-adding the variant. Could get weird.
        # 5. Re-enable the updated product
        #    - NOTE: If the product no longer has any variants, it will remain
        #      disabled as it can no longer be purchased.
        def handle_variants(event)
            product = event.payload

            split = get_mapper(:ProductMapper).split_digital_and_physical(
                product,
                interpolated['custom_fields_map']
            )
            physical = split[:physical]
            digital = split[:digital]

            base_sku = product['additionalProperty'].find { |p|
                p['propertyID'] == 'baseSku'
            }['value']

            wrapper_skus = {
                # Use the provided base_sku if it exists -- otherwise, infer the SKU from the variant list
                physical: base_sku ? "#{base_sku}-P" : get_mapper(:ProductMapper).get_wrapper_sku(physical),
                digital: base_sku ? "#{base_sku}-D" : get_mapper(:ProductMapper).get_wrapper_sku(digital),
            }

            bc_products = @product.get_by_skus(
                wrapper_skus.map {|k,v| v},
                %w[custom_fields options]
            )

            #save skus
            digital_skus = []
            physical_skus = []
            if split[:digital] and split[:physical]
                digital_skus.concat([wrapper_skus[:digital]])
                digital_skus.concat(get_mapper(:ProductMapper).get_product_skus(split[:digital])).join(",")
                physical_skus.concat([wrapper_skus[:physical]])
                physical_skus.concat(get_mapper(:ProductMapper).get_product_skus(split[:physical])).join(",")
            end

            # upsert wrapper products
            split.each do |type, product|
                is_digital = type == :digital ? true : false

                # modify digital
                if is_digital
                    product['name'] = "#{product['name']} (Digital)"
                end

                # BigCommerce requires that product names be unique. In some cases, (like book titles from multiple sources),
                # this may be hard to enforce. In those cases, the product SKUs should still be unique, so we append the SKU
                # to the product title with a `|~` separator. We then set the `page_title` to the original product name so
                # users don't see system values.
                if boolify(options['should_disambiguate'])
                    product['page_title'] = product['name']
                    product['name'] += " |~ " + (is_digital ? wrapper_skus[:digital] : wrapper_skus[:physical])
                end

                wrapper_sku = wrapper_skus[type]
                bc_product = bc_products[wrapper_sku]
                variant_option_name = get_mapper(:OptionMapper).variant_option_name
                bc_option = !bc_product.nil? ? bc_product['options'].select {|opt| opt['display_name'] === variant_option_name}.first : nil

                search_skus = is_digital ? physical_skus : digital_skus


                # ##############################
                # 1. update wrapper product
                # ##############################
                upsert_result = upsert_product(wrapper_sku, product, bc_product, is_digital, search_skus)
                bc_product = upsert_result[:product]

                # clean up custom/meta fields. there are not batch operations so we might as well do them here.
                custom_fields_delete = upsert_result[:custom_fields_delete].select {|field| field['name'] != 'related_product_id'}
                clean_up_custom_fields(custom_fields_delete)
                meta_fields = update_meta_fields(
                    upsert_result[:meta_fields_upsert],
                    upsert_result[:meta_fields_delete],
                )

                bc_product['meta_fields'] = meta_fields

                bc_products[wrapper_sku] = bc_product
                product_id = bc_products[wrapper_sku]['id']

                # ##############################
                # 2. upsert option & option_values
                # ##############################
                option_values_map = get_mapper(:ProductMapper).get_sku_option_label_map(product)
                option_values = option_values_map.map {|k,v| v}
                option_value_operations = get_mapper(:OptionMapper).option_value_operations(bc_option, option_values)
                option = get_mapper(:OptionMapper).map(product_id, bc_option, option_value_operations[:create])
                bc_option = @product_option.upsert(product_id, option)

                # ##############################
                # 3. delete old option_values
                # ##############################
                @product_option_value.delete_all(bc_option, option_value_operations[:delete])

                # ##############################
                # 4. upsert variants
                # ##############################
                variant_skus = get_mapper(:ProductMapper).get_product_skus(product)
                bc_variants = @product_variant.index(product_id)
                mapped_variants = product['model'].select { |m| m['isAvailableForPurchase'] }.map do |variant|
                    bc_variant = bc_variants.select {|v| v['sku'] === variant['sku']}.first
                    opt = get_mapper(:ProductMapper).get_option(variant)
                    bc_option_value = bc_option['option_values'].select {|ov| ov['label'] == opt}.first

                    option_value = get_mapper(:VariantMapper).map_option_value(bc_option_value['id'], bc_option['id'])

                    get_mapper(:VariantMapper).map(
                        variant,
                        [option_value],
                        product_id,
                        bc_variant.nil? ? nil : bc_variant['id'],
                        interpolated['not_purchasable_format_list'],
                        bc_option_value
                    )
                end


                unless (mapped_variants.blank?)
                  bc_product['variants'] = @variant.upsert(mapped_variants)

                  # ##############################
                  # 5. Re-enable the updated product
                  # ##############################
                  @product.enable(product_id)
                end
            end

            bc_physical = bc_products[wrapper_skus[:physical]]
            bc_digital = bc_products[wrapper_skus[:digital]]
            is_delete_physical = split[:physical].nil? && bc_physical
            is_delete_digital = split[:digital].nil? && bc_digital

            # ##############################
            # clean up products that no longer exist
            # ##############################
            if is_delete_physical
                bc_product = bc_products[wrapper_skus[:physical]]
                @product.delete(bc_product['id'])
                bc_physical = false
                bc_product.delete(wrapper_skus[:physical])
            end

            if is_delete_digital
                bc_product = bc_products[wrapper_skus[:digital]]
                @product.delete(bc_product['id'])
                bc_digital = false
                bc_product.delete(wrapper_skus[:digital])
            end

            # ##############################
            # clean up custom field relationships
            # ##############################
            if bc_physical && !bc_digital
                # clean up related_product_id on physical product
                bc_product = bc_physical
                related_custom_field = bc_product['custom_fields'].select {|field| field['name'] == 'related_product_id'}.first
                @custom_field.delete(bc_product['id'], related_custom_field['id']) unless related_custom_field.nil?
            elsif !bc_physical && bc_digital
                # clean up related_product_id on digital product
                bc_product = bc_digital
                related_custom_field = bc_product['custom_fields'].select {|field| field['name'] == 'related_product_id'}.first
                @custom_field.delete(bc_product['id'], related_custom_field['id']) unless related_custom_field.nil?
            elsif bc_physical && bc_digital
                # update/add related_product_id on both products
                bc_physical_related = get_mapper(:CustomFieldMapper).map_one(bc_physical, 'related_product_id', bc_digital['id'])
                bc_digital_related = get_mapper(:CustomFieldMapper).map_one(bc_digital, 'related_product_id', bc_physical['id'])
                @custom_field.upsert(bc_physical['id'], bc_physical_related)
                @custom_field.upsert(bc_digital['id'], bc_digital_related)
            end

            # ##############################
            # emit events
            # ##############################
            if bc_physical
                create_event payload: {
                    product: bc_physical
                }
            end

            if bc_digital
                create_event payload: {
                    product: bc_digital
                }
            end
        end

        def handle_option_list(event)
            product = event.payload

            skus = get_mapper(:ProductMapper).get_product_skus(product)
            wrapper_sku = get_mapper(:ProductMapper).get_wrapper_sku(product)
            all_skus = [].push(*skus).push(wrapper_sku)
            bc_products = @product.get_by_skus(all_skus)

            # upsert child products
            bc_children = []
            custom_fields_delete = []
            meta_fields_upsert = []
            meta_fields_delete = []

            skus.each do |sku|
                bc_product = bc_products[sku]
                result = upsert_product(sku, product, bc_product)
                custom_fields_delete += result[:custom_fields_delete]
                meta_fields_upsert += result[:meta_fields_upsert]
                meta_fields_delete += result[:meta_fields_delete]
                bc_children.push(result[:product])
            end

            # upsert wrapper
            bc_wrapper_product = bc_products[wrapper_sku]
            result = upsert_product(wrapper_sku, product, bc_wrapper_product)
            custom_fields_delete += result[:custom_fields_delete]
            meta_fields_upsert += result[:meta_fields_upsert]
            meta_fields_delete += result[:meta_fields_delete]

            is_default_map = get_mapper(:ProductMapper).get_is_default(product)

            # update modifier
            sku_option_map = get_mapper(:ProductMapper).get_sku_option_label_map(product)
            modifier_updates = get_mapper(:ModifierMapper).map(
                bc_wrapper_product,
                bc_children,
                sku_option_map,
                is_default_map
            )
            @modifier.upsert(result[:product]['id'], modifier_updates[:upsert])

            clean_up_custom_fields(custom_fields_delete)
            clean_up_modifier_values(modifier_updates[:delete])
            meta_fields = update_meta_fields(meta_fields_upsert, meta_fields_delete)

            if product['is_visible']
              # If the product should be enabled, re-enable it
              @product.enable(result[:product]['id'])
            end

            product['meta_fields'] = meta_fields
            product['modifiers'] = modifier_updates[:upsert]
            create_event payload: {
                product: product,
                parent: result[:product],
                children: bc_children
            }
        end

        private

        def initialize_clients
            @variant = initialize_client(:Variant)
            @product_variant = initialize_client(:ProductVariant)
            @product_option = initialize_client(:ProductOption)
            @product_option_value = initialize_client(:ProductOptionValue)
            @product = initialize_client(:Product)
            @custom_field = initialize_client(:CustomField)
            @meta_field = initialize_client(:MetaField)
            @modifier = initialize_client(:Modifier)
            @modifier_value = initialize_client(:ModifierValue)
        end

        def initialize_client(class_name)
            klass = ::BigcommerceProductAgent::Client.const_get(class_name.to_sym)
            return klass.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )
        end

        def get_mapper(class_name)
            return ::BigcommerceProductAgent::Mapper.const_get(class_name.to_sym)
        end

        def upsert_product(sku, product, bc_product = nil, is_digital=false, search_skus=[])
            custom_fields_updates = get_mapper(:CustomFieldMapper).map(
                interpolated['custom_fields_map'],
                product,
                bc_product
            )

            product_id = bc_product['id'] unless bc_product.nil?

            payload = get_mapper(:ProductMapper).payload(
                sku,
                product,
                product_id,
                {
                    additional_search_terms: search_skus,
                    custom_fields: custom_fields_updates[:upsert]
                },
                is_digital,
            )

            payload[:is_visible] = false
            # NOTE:  Products are intentionally upserted as disabled so that users
            # don't see an incomplete listing (particularly when leveraging variants)
            # The variant and option_list methods will re-enable products after the
            # upsert is complete.

            bc_product = @product.upsert(payload, {
                include: %w[custom_fields variants options].join(',')
            })

            # Metafields need to be managed separately. Intentionally get them _AFTER_
            # the upsert so that we have the necessary resource_id (bc_product.id)
            meta_fields_updates = get_mapper(:MetaFieldMapper).map(
                interpolated['meta_fields_map'],
                product,
                bc_product,
                @meta_field.get_for_product(bc_product['id']),
                interpolated['meta_fields_namespace']
            )

            {
                product: bc_product,
                custom_fields_delete: custom_fields_updates[:delete],
                meta_fields_upsert: meta_fields_updates[:upsert],
                meta_fields_delete: meta_fields_updates[:delete]
            }
        end

        def clean_up_custom_fields(custom_fields)
            custom_fields.each do |field|
                @custom_field.delete(field['product_id'], field['id'])
            end
        end

        def clean_up_modifier_values(modifier_values)
            modifier_values.each do |field|
                @modifier_value.delete(field[:product_id], field[:modifier_id], field[:value_id])
            end
        end

        def update_meta_fields(upsert_fields, delete_fields)
            meta_fields = []

            upsert_fields.each do |field|
                meta_fields << @meta_field.upsert(field)
            end

            delete_fields.each do |field|
                if field[:resource_id] && field[:id]
                    @meta_field.delete(field[:resource_id], field[:id])
                end
            end

            meta_fields
        end
    end
end
