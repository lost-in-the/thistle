# frozen_string_literal: true

class Item < ActiveRecord::Base
  self.table_name = 'items'
  belongs_to :order, inverse_of: :items
end
