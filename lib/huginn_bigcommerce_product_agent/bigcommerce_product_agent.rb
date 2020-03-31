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

        def default_options
            {
                'store_hash' => '',
                'client_id' => '',
                'access_token' => '',
                'custom_fields_map' => {},
                'meta_fields_map' => {},
                'meta_fields_namespace' => '',
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
                errors.add(:base, "if provided, custom_fields_map must be a hash")
            end

            unless options['meta_fields_map'].is_a?(Hash)
                errors.add(:base, "if provided, meta_fields_map must be a hash")
            end

            if options['meta_fields_map']
                errors.add(:base, "if meta_fields_map is provided, meta_fields_namespace is required") if options['meta_fields_namespace'].blank?
            end
        end

        def working?
            received_event_without_error?
        end

        def check
            initialize_clients()
            handle interpolated['payload'].presence || {}
        end

        def receive(incoming_events)
            initialize_clients()
            incoming_events.each do |event|
                handle(event)
            end
       end

        def handle(event)
            product = event.payload

            skus = ::BigcommerceProductAgent::Mapper::ProductMapper.get_product_skus(product)
            wrapper_sku = ::BigcommerceProductAgent::Mapper::ProductMapper.get_wrapper_sku(product)
            all_skus = [].push(*skus).push(wrapper_sku)
            bc_products = @product.get_by_skus(all_skus)

            # upsert child products
            bc_children = []
            custom_fields_delete = []
            meta_fields_upsert = []
            meta_fields_delete = []

            skus.each do |sku|
                bc_product = bc_products[sku]
                result = upsert(sku, product, bc_product)
                custom_fields_delete += result[:custom_fields_delete]
                meta_fields_upsert += result[:meta_fields_upsert]
                meta_fields_delete += result[:meta_fields_delete]
                bc_children.push(result[:product])
            end

            # upsert wrapper
            bc_wrapper_product = bc_products[wrapper_sku]
            result = upsert(wrapper_sku, product, bc_wrapper_product)
            custom_fields_delete += result[:custom_fields_delete]
            meta_fields_upsert += result[:meta_fields_upsert]
            meta_fields_delete += result[:meta_fields_delete]

            is_default_map = ::BigcommerceProductAgent::Mapper::ProductMapper.get_is_default(product)

            # update modifier
            sku_option_map = ::BigcommerceProductAgent::Mapper::ProductMapper.get_sku_option_label_map(product)
            modifier_updates = ::BigcommerceProductAgent::Mapper::ModifierMapper.map(
                bc_wrapper_product,
                bc_children,
                sku_option_map,
                is_default_map
            )
            @modifier.upsert(result[:product]['id'], modifier_updates[:upsert])

            clean_up_custom_fields(custom_fields_delete)
            clean_up_modifier_values(modifier_updates[:delete])
            meta_fields = update_meta_fields(meta_fields_upsert, meta_fields_delete)

            product['meta_fields'] = meta_fields
            product['modifiers'] = modifier_updates[:upsert]
            create_event payload: {
                product: product,
                parent: result[:product],
                children: bc_children,
            }
        end

        private

        def initialize_clients
            @product = ::BigcommerceProductAgent::Client::Product.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )

            @custom_field = ::BigcommerceProductAgent::Client::CustomField.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )

            @meta_field = ::BigcommerceProductAgent::Client::MetaField.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )

            @modifier = ::BigcommerceProductAgent::Client::Modifier.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )

            @modifier_value = ::BigcommerceProductAgent::Client::ModifierValue.new(
                interpolated['store_hash'],
                interpolated['client_id'],
                interpolated['access_token']
            )
        end

        def upsert(sku, product, bc_product = nil)
            custom_fields_updates = ::BigcommerceProductAgent::Mapper::CustomFieldMapper.map(
                interpolated['custom_fields_map'],
                product,
                bc_product
            )

            product_id = bc_product['id'] unless bc_product.nil?

            payload = ::BigcommerceProductAgent::Mapper::ProductMapper.payload(
                sku,
                product,
                product_id,
                { custom_fields: custom_fields_updates[:upsert] }
            )

            bc_product = @product.upsert(payload)

            # Metafields need to be managed separately. Intentionally get them _AFTER_
            # the upsert so that we have the necessary resource_id (bc_product.id)
            meta_fields_updates = ::BigcommerceProductAgent::Mapper::MetaFieldMapper.map(
                interpolated['meta_fields_map'],
                product,
                bc_product,
                @meta_field.get_for_product(bc_product['id']),
                interpolated['meta_fields_namespace']
            )

            return {
                product: bc_product,
                custom_fields_delete: custom_fields_updates[:delete],
                meta_fields_upsert: meta_fields_updates[:upsert],
                meta_fields_delete: meta_fields_updates[:delete],
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
                @meta_field.delete(field[:resource_id], field[:id])
            end

            return meta_fields
        end
    end
end
