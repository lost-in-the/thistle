# frozen_string_literal: true

module FixtureSeed
  def self.create(connection)
    connection.transaction do
      order = Order.create!(id: 1, reference: ' retained-order-1 ')
      Item.create!(id: 1, order: order, quantity: 2)
      Item.create!(id: 2, order: order, quantity: 3)
      connection.execute("INSERT INTO host_metadata VALUES ('los139-schema-v1', 'los139-seed-v1')")
    end
  end
end
