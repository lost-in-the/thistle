# frozen_string_literal: true

# Called only after the dedicated app schema is proven empty, with the explicit
# first-use switch. No down/reset path is provided by this fixture.
class CreateFixture < ActiveRecord::Migration[7.1]
  def up
    create_table(:orders) { |t| t.string :reference, null: false }
    create_table(:items) { |t| t.bigint :order_id, null: false; t.integer :quantity, null: false }
    add_index(:items, :order_id, name: 'items_order_id_idx')
    add_foreign_key(:items, :orders, name: 'fk_items_orders')
    create_table(:host_metadata, id: false) { |t| t.string :schema_version, null: false; t.string :seed_version, null: false }
  end
end
