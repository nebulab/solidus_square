# frozen_string_literal: true

SolidusSquare.configure do |config|
  config.square_environment = 'sandbox'
  config.square_access_token = ENV['SQUARE_ACCESS_TOKEN']
  config.square_location_id = ENV['SQUARE_LOCATION_ID'] || 'LOCATION'
end

module SquareHelpers
  def find_or_create_square_order_id_on_sandbox(order)
    client = ::Square::Client.new(
      access_token: SolidusSquare.config.square_access_token,
      environment: "sandbox"
    )
    square_order = detect_order_by_order_number(client, order.number)
    return square_order if square_order.present?

    client.orders.create_order(body: order_payload(order)).data.order[:id]
  end

  def detect_order_by_order_number(client, order_number)
    order_ids_result = client.orders.search_orders(search_params(order_number))
    return if order_ids_result.data.nil?

    order_ids_result.data.order_entries.first[:order_id]
  end

  def order_payload(order)
    {
      idempotency_key: SecureRandom.uuid,
      order: {
        location_id: SolidusSquare.config.square_location_id,
        reference_id: order.number,
        customer_id: Base64.urlsafe_encode64(order.email),
        source: {
          name: "solidus_square_test_#{order.number}"
        },
        line_items: [{
          name: 'Order total',
          quantity: '1',
          base_price_money: {
            amount: Money.from_amount(order.total).fractional,
            currency: order.currency
          }
        }],
      }
    }
  end

  def search_params(order_number)
    {
      body: {
        location_ids: [SolidusSquare.config.square_location_id],
        limit: 1,
        return_entries: true,
        query: {
          filter: {
            source_filter: {
              source_names: ["solidus_square_test_#{order_number}"]
            }
          }
        }
      }
    }
  end
end
