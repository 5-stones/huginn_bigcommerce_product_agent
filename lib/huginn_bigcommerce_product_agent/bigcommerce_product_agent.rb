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
        'should_disambiguate' => false,
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

        if options.has_key?('track_inventory') && boolify(options['track_inventory']).nil?
          errors.add(:base, 'when provided, `track_inventory` must be true or false')
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
      data = event.payload
      raw_products = data['products']
      results = []

      # Loop through the provided raw_products and perform the upsert
      # This process will upsert the core product record and the custom/meta
      # fields from the Acumen data.
      additional_data = {
        additional_search_terms: [],
      }

      raw_products.each do |raw_product|
        additional_data[:additional_search_terms].push(raw_product['sku'])
      end

      bc_products = lookup_existing_products(raw_products)
      existing_skus = bc_products.map { |p| p['sku'] }

      # This agent requires us to make several requests due to limitations in the BigCommerce API.
      # Specifically, Product records must be created and deleted individually, and, though meta fields can
      # be managed in "bulk", the batch is limited to specific product IDs.
      #
      # Additionally, this agent sets a `related_product_ids` field as a CSV string of each product ID in
      # the bundle. Because this field expects the BigCommerce ID, this has to happen _after_ product
      # creation / deletion.
      #
      # For the sake of performance, we group products into three buckets: create, delete, update.
      # From there, we run through the following process:
      #
      #     *  Create new products
      #     *  Delete discontinued products
      #     *  Update existing products & custom fields
      #     *  Update meta fields
      #
      # The existing product update will include data for products created in step one. This is intentional
      # because the update step allows us to populate custom fields in bulk (including the `related_product_ids`
      # field), so we still come out ahead in terms of overall performance.

      to_create = raw_products.select { |p| p['productAvailability'] != 'not available' && !existing_skus.include?(p['sku'])}
      to_delete = raw_products.select { |p| p['productAvailability'] == 'not available' && existing_skus.include?(p['sku'])}
      to_update = raw_products.select { |p| p['productAvailability'] != 'not available' && existing_skus.include?(p['sku'])}

      mapped_products = [] # Contains an array of { :bc_payload, :raw_product } hashes

      #  Delete all inactive products
      to_delete.each do |p|
          bc_product = bc_products.find { |bc| bc['sku'] == p['sku'] }
          delete_inactive_product(bc_product)
      end

      # A Note regarding the nil checks below. In order to improve the efficiency
      # of this agent, we process requests in batch wherever possible. However,
      # we don't want errors with one product to prevent others in the bundle from
      # processing.
      #
      # Methods that process single records intentionally return `nil` in the event
      # of an error to facilitate this, and `nil` entries are excluded from the
      # batch processes. Additionally, any such processing errors are emitted as
      # error events with `status: 500` to facilitate reporting.

      #-----   Handle the creation of any new products   -----#
      to_create.each do |raw_product|
        bc_product = create_new_product(raw_product, additional_data)
        unless bc_product.nil?
          mapped_products.push({ bc_payload: bc_product, raw_product: raw_product })
        end
      end

      #-----   Process updates for existing products   -----#
      to_update.each do |raw_product|
        bc_product = bc_products.find { |bc| bc['sku'] == raw_product['sku'] }
        mapped_product = process_updates(raw_product, bc_product, additional_data)

        unless mapped_product.nil?
          mapped_products.push(mapped_product)
        end
      end

      #-----   Handle final upserts   -----#
      unless mapped_products.blank?
        # NOTE: An empty array here likely indicates that a title has been removed
        # from sale completely and is not available in any format. Most of the
        # time, mapped_products should have at least one item.
        #
        # In rare cases, it may mean that all products resulted in a processing
        # error, but since those are tracked individually, we don't need to issue
        # any errors here.
        upsert_products(mapped_products)
      end
    end

    # Attempt to find an existing BigCommerce product by SKU
    # Returns nil if no matching product is found.
    def lookup_existing_products(raw_products)
      begin
        bc_products = @product_client.get_by_skus(raw_products.map { |r| r['sku'] })

        return bc_products
      rescue BigCommerceProductError => e
        create_event payload: {
          status: e.status,
          scope: e.scope,
          message: e.message,
          data: e.data,
        }

        raise e
        # This exception is intentionally rethrown because it means we were unable
        # lookup existing BigCommerce records. (If there were no matching SKUs, the
        # response would be an empty array). In this case, we don't have enough
        # information to accurately process the incoming raw products, so we must
        # fail.
      end
    end

    def delete_inactive_product(bc_product)
      begin
        @product_client.delete(bc_product['id'])
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'delete inactive_product',
          e.message,
          bc_product['id'],
          { sku: bc_product['sku'] },
          e,
        ))
      end
    end

    # Handles the creation of new product records
    def create_new_product(raw_product, additional_data)
      begin
        bc_payload = map_product(raw_product, nil, additional_data)
        custom_fields = map_custom_fields(raw_product, nil)
        bc_payload['custom_fields'] = custom_fields[:upsert]
        return @product_client.create(bc_payload, { include: 'custom_fields' })
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'create_new_product',
          e.message,
          nil,
          { sku: raw_product['sku'] },
          e
        ))
      end

      return nil
    end

    # Generates an update payload for the provided product records
    # Returns a hash containing { :bc_payload, :raw_product }
    def process_updates(raw_product, bc_product, additional_data)
      custom_fields = map_custom_fields(raw_product, bc_product)

      custom_fields[:delete].each do |field|
        begin
          # Delete custom fields that are no longer used
          @custom_field_client.delete(bc_product['id'], field['id'])
        rescue BigCommerceProductError => e
          emit_error(e)
        rescue => e
          emit_error(BigCommerceProductError.new(
            500,
            'delete_custom_fields',
            e.message,
            bc_product['id'],
            { sku: bc_product['sku'], field_id: field['id'] },
            e
          ))
        end
      end

      bc_payload = map_product(raw_product, bc_product, additional_data)

      if bc_payload.present?
        bc_payload['custom_fields'] = custom_fields[:upsert]
        return { bc_payload: bc_payload, raw_product: raw_product }
      else
        return nil
      end
    end

    # Sends a batch update request for the provided products
    # NOTE: This process also sets the `related_product_ids` custom field
    def upsert_products(mapped_products)
      product_ids = mapped_products.map { |p| p[:bc_payload]['id'] }
      results = {}

      product_data = mapped_products.map do |p|
        bc_payload = p[:bc_payload]
        raw_product = p[:raw_product]

        meta_fields = update_meta_fields(raw_product, bc_payload)
        results[raw_product['sku']] = {
          raw_product: raw_product,
          meta_fields: meta_fields[:upsert],

        }

        #-----  Set related_product_ids  -----#
        related_product_ids = product_ids.select { |id| id != bc_payload['id'] }
        field = {
          'name': 'related_product_ids',
          'value': related_product_ids * ',' # concatenate as a CSV
        }

        unless related_product_ids.empty?
          if bc_payload['custom_fields'].blank?
            bc_payload['custom_fields'] = []
          end

          bc_payload['custom_fields'].push(field)
        end

        # return the finalized payload
        bc_payload
      end

      begin
        @product_client.update_batch(product_data, { include: 'custom_fields' }).each do |p|
          result = results[p['sku']]
          result[:custom_fields] = p['custom_fields']
          result[:bc_product] = p

          create_event payload: {
            product: result,
            status: 200,
          }
        end
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'upsert_products',
          e.message,
          nil,
          { sku: product_data.map { |p| p[:sku] } },
          e
        ))
      end
    end

    # Map the raw_product record to bc_product fields. The bc_product passed in may be null
    # if the product does not exist yet in BigCommerce.
    def map_product(raw_product, bc_product, additional_data)
      bc_payload = nil

      begin
        # if track inventory on the agent is true set track inventory to product level track inventory
        track_inventory = boolify(options['track_inventory']).nil? ? true : boolify(options['track_inventory'])
        if (track_inventory)
          track_inventory = boolify(raw_product['trackInventory'])
        end
        bc_payload = get_mapper(:ProductMapper).map_payload(raw_product, bc_product, additional_data, track_inventory)
        bc_payload['id'] = bc_product['id'] unless bc_product.nil? || bc_product['id'].nil?
        # NOTE: bc_product will be nil when this is called with `to_create` products

        if bc_payload[:categories].empty?
          # If categories is empty keep existing categories because categories should never be empty
          bc_payload[:categories] = bc_product['categories'] unless bc_product.nil? || bc_product['categories'].nil?
        end

        if bc_payload[:type] == 'digital'
          bc_payload[:name].concat(' (Digital)')
        end

        # BigCommerce requires that product names be unique. In some cases, (like book titles from multiple sources),
        # this may be hard to enforce. In those cases, the product SKUs should still be unique, so we append the SKU
        # to the product title with a `|~` separator. We then set the `page_title` to the original product name so
        # users don't see system values.
        #
        # page_title is the user-facing display value for product pages.
        if boolify(options['should_disambiguate'])
           bc_payload[:page_title] = bc_payload[:name]
           bc_payload[:name] = bc_payload[:name] + " |~ " + raw_product['sku']
        end

        return bc_payload
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'map_product',
          e.message,
          bc_product['id'],
          { sku: bc_product['sku'] },
          e
        ))
      end

      return nil
    end

    #  Maps custom field values from the raw_product to the bc_payload
    #  NOTE: Because custom fields can be included in product upsert requests,
    #  this function is only _mapping_ the data.
    def map_custom_fields(raw_product, bc_payload)
      current_fields = bc_payload.nil? ? [] : bc_payload['custom_fields']

      begin
        return get_mapper(:CustomFieldMapper).map(options['custom_fields_map'], raw_product, bc_payload, current_fields, options['meta_fields_namespace'])
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'map_custom_fields',
          e.message,
          bc_payload['id'],
          { sku: bc_payload['sku'] },
          e
        ))
      end

      return nil
    end

    #  Manages meta field values for the provided product records.
    #  NOTE: Because meta fields have to be managed separately, this function will
    #  map the raw_product data and also handle any delete/create/update requests.
    def update_meta_fields(raw_product, bc_payload)
      current_fields = nil

      begin
        current_fields = @meta_field_client.get_for_product(bc_payload['id'])
      rescue BigCommerceProductError => e
        emit_error(e)
        return nil
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'get_meta_fields',
          e.message,
          bc_payload['id'],
          { sku: bc_payload['sku'] },
          e
        ))
        return nil
      end

      begin
        fields = get_mapper(:MetaFieldMapper).map(options['meta_fields_map'], raw_product, bc_payload, current_fields, options['meta_fields_namespace'])

        # Delete fields
        fields[:delete].each do |field|
            begin
              @meta_field_client.delete(bc_payload['id'], field['id'])
            rescue BigCommerceProductError => e
              emit_error(e)
            rescue => e
              emit_error(BigCommerceProductError.new(
                500,
                'delete meta_fields',
                e.message,
                bc_payload['id'],
                { sku: bc_payload['sku'] },
                e
              ))
            end
        end

        # Upsert fields
        fields[:upsert].each do |field|
          begin
            @meta_field_client.upsert(bc_payload['id'], field)
          rescue BigCommerceProductError => e
            emit_error(e)
          rescue => e
            emit_error(BigCommerceProductError.new(
              500,
              'upsert_meta_fields',
              e.message,
              bc_payload['id'],
              { sku: bc_payload['sku'] },
              e
            ))
          end
        end

        return fields
      rescue BigCommerceProductError => e
        emit_error(e)
      rescue => e
        emit_error(BigCommerceProductError.new(
          500,
          'map_meta_fields',
          e.message,
          bc_payload['id'],
          { sku: bc_payload['sku'] },
          e
        ))
      end

      return nil
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

    #  Takes a BigCommerceProductError and emits the underlying data as an error payload
    #  to assist with error reporting. It is recommended that these errors be consolidated
    #  with a Digest Agent and reported as a summary.
    def emit_error(error)

      payload = {
        status: error.status,
        message: error.message,
        scope: error.scope,
        product_identifier: error.product_identifier,
        data: error.data,
      }

      Rails.logger.debug({
        error: payload,
        trace: error.backtrace
      })

      create_event({ payload: payload })
    end
  end
end
