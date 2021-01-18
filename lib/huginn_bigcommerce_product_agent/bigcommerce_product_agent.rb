# frozen_string_literal: true

require 'json'

################################################################################
#  TODO:    REMOVE THIS TODO WHEN CHANGES ARE COMPLETE
#
# This file is effectively an outline of what the updated agent should look like.
# The previous version was monolithic and often hard to follow. The goal here is
# to make this easier to read/work with -- especially for those who may not have
# full context for the project.
#
# we should avoid using `product` as a variable name and prefix it so it is
# explicitly clear where the data came from:
#
#     `acumen_` for Acumen, `bc_` for BigCommerce.
#
# Reuse as much of the existing logic as possible, but add comments detailing what
# each function is doing. The client classes are probably solid as is, and the
# mappers are likely _mostly_ set (though desperately in need of better commenting)
#
# Functionality wise, the biggest change here is that we're abandoning Modifiers
# and Variants. All products will be synced to BigCommerce individually. The
# Modifier, ProductOption, and Variant classes are all tied to the old sync, so
# they've been removed (though there are some lingering _references_, so clean
# those up as you go)
#
# The payload coming into this agent is an array of Acumen products. The array
# effectively represents a "bundle" of all the formats for a given product title.
#
# The old input structure was:
#
# {
#   id,
#   name,
#   sku,
#   price,
#   ...
#   model: { id, sku, price }
# }
#
# So you'll see a lot of references thoughout the mappers pulling data out of the
# `model` to populate a variant. That `model` is going away. Everything you need to
# set in BigCommerce will be on the `product` proper. Essentially, any places you see
# product['model'][...] would now be product[...]
#
# Other than that, though, the incoming data will not be changing. We're just tidying
# up how we work with it.
#
# Comment "everything". The logic here is inherently monolithic, so we want to make
# sure that anyone new to the project (and anyone who hasn't looked at it for a while)
# can quickly and easily see what each piece of the agent is doing. No more "let me take
# 45 minutes to relearn what's happening here" whenever we need to make a change.
#
# The old_files folder contains the previous version of all the files for this agent.
# Pull from that location as a reference when needed, and delete the folder after
# things are cleaned up.
#
################################################################################

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

        begin
          bc_product = @product_client.get_by_sku(raw_product['sku'])

          if (bc_product)
            # Disable the product as we process the upsert to ensure users don't see incorrect data
            @product_client.disable(bc_product['id'])
          end

          # Process product updates
          bc_product = upsert_product(raw_product, bc_product, additional_data)
          custom_fields = update_fields(raw_product, bc_product, get_mapper(:CustomFieldMapper), options['custom_fields_map'], @custom_field_client)
          meta_fields = update_fields(raw_product, bc_product, get_mapper(:MetaFieldMapper), options['meta_fields_map'], @meta_field_client)

          # This will be emitted later as an event
          results.push({
            bc_product: bc_product,
            custom_fields: custom_fields,
            meta_fields: meta_fields,
            acumen_data: raw_product
          })

        rescue => e
          # TODO emit an error event here:
          # {
          #   status: 404 | 500
          #   message:
          #   raw_product:
          # }
          # We will need error reporting added for this payload with a trigger agent,
          # consolidation agent, and a reporting agent look at existing error reporting
          # for guidance
          create_event payload: {
            status: 500,
            message: e.message(),
            trace: e.backtrace.join('\n'),
            raw_product: raw_product,
          }

        end

      end

      results = set_related_product_ids(results)

      # After updates have been processed, loop through the created BigCommerce
      # products and reactivate those that are not already active.
      #
      # NOTE: This happens last because there is an intermediate step in the upsert
      # that sets the related_product_ids field
      results.each do |data|
        begin
          raw_product = data[:acumen_data]
          if (raw_product['isAvailableForPurchase'])
            # Following all updates, if the product is available for purchase
            @product_client.enable(data[:bc_product]['id'])
          end

          # TODO Emit each item in the `results` array as an event payload and _add_ a `status` key with a value of 200

          create_event payload: {
            product: data,
            status: 200
          }
        rescue => e
          # TODO emit an error event here:
          # {
          #   status: 404 | 500
          #   message:
          #   trace:
          #   raw_product:
          # }
          # We will need error reporting added for this payload with a trigger agent,
          # consolidation agent, and a reporting agent look at existing error reporting
          # for guidance
          create_event payload: {
            status: 500,
            message: e.message(),
            trace: e.backtrace.join('\n'),
            raw_product: raw_product,
          }
        end
      end
    end

    # Upsert the core product record in BigCommerce This handles all fields stored
    # directly on the BigCommerce product object: name, sku, price, etc.
    #
    # The bc_product passed in may be null if the product does not exist yet in BigCommerce.
    # If provided, bc_product['id'] will be used to upsert new data to an existing product.
    # Otherwise a new record will be created.
    def upsert_product(raw_product, bc_product, additional_data)

      # TODO format the payload based on the BigCommerce product API (v3)
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
         payload[:name].concat(" |~ " + raw_product['sku'])
      end

      if bc_product
        payload[:id] = bc_product['id']
      end


      return @product_client.upsert(payload)
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

      # Delete fields
      fields[:delete].each do |field|
          client.delete(field['product_id'], field['id'])
      end

      # Upsert fields
      fields[:upsert].each do |field|
          client.upsert(field['product_id'], field)
      end

      return fields
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
      # TODO: The value of `related_product_ids` should be set to a CSV of all other formats.
      # So, if products 1, 2, 3, and 4 are all different formats of the same title, Product 1 should
      # have a value of `2,3,4`.
      #
      # Additionally, the custom_fields key in the hash should be _updated_ to include the
      # related_product_ids field. And the updated hash should be returned.

      product_ids = []

      product_data.each do |product_hash|
        product_ids.push(product_hash[:bc_product]['id'])
      end

      product_data.each do |product_hash|
        product_ids.delete(product_hash[:bc_product]['id'])
        product_hash[:custom_fields]['related_product_ids'] = product_ids * ','
        product_ids.push(product_hash[:bc_product]['id'])
      end

      return product_data
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
