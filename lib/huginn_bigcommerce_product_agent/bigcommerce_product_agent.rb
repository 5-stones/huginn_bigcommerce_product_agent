# frozen_string_literal: true

require 'json'

module Agents
  class BigcommerceProductAgent < Agent
    include WebRequestConcern

    can_dry_run!
    default_schedule 'never'

    # TODO:   Provide a more detailed agent description. Including details of
    # each option and how that option is used
    description <<-MD
      Takes an array of related products and upserts them into BigCommerce.
    MD

    def default_options
      {
        'store_hash' => '',
        'client_id' => '',
        'access_token' => '',
        'custom_fields_map' => {},
        'meta_fields_map' => {},
        'meta_fields_namespace' => '',
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
      raw_products = event.payload
      results = []

      # Loop through the provided raw_products and perform the upsert
      # This process will upsert the core product record and the custom/meta
      # fields from the Acumen data.
      additional_data = {
        additional_search_terms: [],
      }

      raw_products['products'].each do |raw_product|
        additional_data[:additional_search_terms].push(raw_product['sku'])
      end

      raw_products['products'].each do |raw_product|

        bc_product = lookup_existing_product(raw_product)

        if (bc_product && !boolify(raw_product['isAvailableForPurchase']))
          #  Before we do anything else, check to see if the product is actually
          #  active. If not, we need to delete it.
          delete_inactive_product(bc_product)
        else
          #  We either have an active product that needs to be updated or a new
          # product that needs to be created.
          if (disable_existing_product(bc_product))

            begin
              # Only process updates if the existing product has been disabled
              bc_product = upsert_product(raw_product, bc_product, additional_data)
              custom_fields = update_fields(raw_product, bc_product, get_mapper(:CustomFieldMapper), options['custom_fields_map'], @custom_field_client)
              meta_fields = update_fields(raw_product, bc_product, get_mapper(:MetaFieldMapper), options['meta_fields_map'], @meta_field_client)

              # This will be emitted later as an event
              results.push({
                bc_product: bc_product,
                custom_fields: custom_fields,
                meta_fields: meta_fields,
                raw_product: raw_product
              })

            rescue => e
              log({ raw_product: raw_product, bc_product: bc_product, error: e })
              # Log the error and move on. Any errors caught here have already been handled and reported as error events.
              # We are swallowing this exception because a failure with one product should not block the upsert of another.
            end

          end

        end
      end

      if results.length() > 1
        results = set_related_product_ids(results)
      end

      # After updates have been processed, loop through the created BigCommerce
      # products and reactivate those that are not already active.
      #
      # NOTE: This happens last because there is an intermediate step in the upsert
      # that sets the related_product_ids field
      results.each do |data|
        begin
          enable_updated_product(data[:bc_product])

          create_event payload: {
            product: data,
            status: 200
          }
        rescue => e
          create_event payload: {
            status: 500,
            scope: 'enable_updated_product',
            message: e.message(),
            trace: e.backtrace.join('\n'),
            product_data: data,
          }
        end
      end
    end

    # Attempt to find an existing BigCommerce product by SKU
    # Returns nil if no matching product is found.
    def lookup_existing_product(raw_product)
      begin
        bc_product = @product_client.get_by_sku(raw_product['sku'])
      rescue => e
        create_event payload: {
          status: 500,
          scope: 'lookup_existing_product',
          message: e.message,
          trace: e.backtrace.join('\n'),
          raw_product: raw_product,
        }

        # Rethrow the exception
        raise e
      end
    end

    def delete_inactive_product(bc_product)
      begin
        @product_client.delete(bc_product['id'])
      rescue => e
        create_event payload: {
          status: 500,
          scope: 'delete_inactive_product',
          message: e.message,
          trace: e.backtrace.join('\n'),
          bc_product: bc_product,
        }
      end
    end

    # If the product already exists in BigCommerce, disable it before processing
    # any updates. Returns true if the product was successfully disabled
    def disable_existing_product(bc_product)

      if (bc_product.nil?)
        # If no product exists yet, there is nothing to disable. Return a successful response
        return true
      end

      begin
        # Disable the product as we process the upsert to ensure users don't see incorrect data
        @product_client.disable(bc_product['id'])
        return true

      rescue => e
        create_event payload: {
          status: 500,
          scope: 'disable_existing_product',
          message: e.message,
          trace: e.backtrace.join('\n'),
          bc_product_id: id,
        }

        return false
      end
    end

    # Fires after updates have been processed and re-enables the product
    def enable_updated_product(bc_product)
      begin
        @product_client.enable(bc_product['id'])
        return true

      rescue => e
        create_event payload: {
          status: 500,
          scope: 'enable_existing_product',
          message: e.message,
          trace: e.backtrace.join('\n'),
          bc_product_id: id,
        }

        return false
      end
    end


    # Upsert the core product record in BigCommerce This handles all fields stored
    # directly on the BigCommerce product object: name, sku, price, etc.
    #
    # The bc_product passed in may be null if the product does not exist yet in BigCommerce.
    # If provided, bc_product['id'] will be used to upsert new data to an existing product.
    # Otherwise a new record will be created.
    def upsert_product(raw_product, bc_product, additional_data)

      begin
        payload = get_mapper(:ProductMapper).map_payload(raw_product, additional_data)

        if payload[:type] == 'digital'
          payload[:name].concat(' (Digital)')
        end

        # BigCommerce requires that product names be unique. In some cases, (like book titles from multiple sources),
        # this may be hard to enforce. In those cases, the product SKUs should still be unique, so we append the SKU
        # to the product title with a `|~` separator. We then set the `page_title` to the original product name so
        # users don't see system values.
        #
        # page_title is the user-facing display value for product pages.
        if boolify(options['should_disambiguate'])
           payload[:page_title] = payload[:name]
           payload[:name] = payload[:name] + " |~ " + raw_product['sku']
        end

        if bc_product
          payload[:id] = bc_product['id']
        end


        return @product_client.upsert(payload)
      rescue => e

        create_event payload: {
          status: 500,
          scope: 'upsert_product',
          message: e.message(),
          trace: e.backtrace.join('\n'),
          product_payload: payload,
        }

        # Rethrow the initial exception
        raise e
      end
    end

    # Manages the custom/meta fields for the product. Since we don't maintain a _link_ between the
    # Custom/Meta Fields in BigCommerce and their associated data in Acumen, we don't have a very
    # reliable way to fetch/update individual fields.
    #
    # Instead, this function fetches _all_ the product fields, and we use the field name to map
    # them to the correct Acumen data.
    #
    # Additionally, BigCommerce does not allow _blank_ values in Custom/Meta Fields, so if field data
    # is removed from Acumen, then we'll need to _delete_ the associated field in BigCommerce.
    #
    # It is also important to note that this function _will not_ set `related_product_ids`. That
    # field is managed by a separate function.
    def update_fields(raw_product, bc_product, mapper, map, client)
      current_fields = client.get_for_product(bc_product['id'])
      fields = mapper.map(map, raw_product, bc_product, current_fields, options['meta_fields_namespace'])

      begin
        current_fields = client.get_for_product(bc_product['id'])

        fields = mapper.map(map, raw_product, bc_product, current_fields, options['meta_fields_namespace'])

        # Delete fields
        fields[:delete].each do |field|
            client.delete(bc_product['id'], field['id'])
        end

        # Upsert fields
        fields[:upsert].each do |field|
            client.upsert(bc_product['id'], field)
        end

        return fields
      rescue => e

        create_event payload: {
          status: 500,
          scope: 'update_fields',
          field_mapper: mapper,
          message: e.message(),
          trace: e.backtrace.join('\n'),
          field_map: map,
          raw_product: raw_product,
          bc_product: bc_product,
          current_fields: current_fields,
        }

        # Rethrow the initial exception
        raise e
      end
    end

    # This function manages the `related_product_ids` field which is used to link
    # different product formats together.
    # Each item in the provided array will have the following structure:
    #
    #     {
    #       bc_product -- the BigCommerce product record
    #       custom_fields -- Custom Fields in BigCommerce
    #       meta_fields -- Meta Fields in BigCommerce
    #       acumen_data -- The Acumen product record
    #     }
    #
    def set_related_product_ids(product_data)
      begin
        product_ids = []

        product_data.each do |product_hash|
          product_ids.push(product_hash[:bc_product]['id'])
        end

        product_data.each do |product_hash|
          product_ids.delete(product_hash[:bc_product]['id'])

          field = {
            'name': 'related_product_ids',
            'value': product_ids * ',',
          }


          @custom_field_client.upsert(product_hash[:bc_product]['id'], field)


          product_hash[:custom_fields][:upsert].push(field)
          product_ids.push(product_hash[:bc_product]['id'])
        end

        return product_data

      rescue => e
        create_event payload: {
          status: 500,
          scope: 'set_related_product_ids',
          message: e.message(),
          trace: e.backtrace.join('\n'),
          data: product_data,
        }
      end
    end

    private

    def initialize_clients
        @product_client = initialize_client(:Product)
        @custom_field_client = initialize_client(:CustomField)
        @meta_field_client = initialize_client(:MetaField)
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
  end
end
