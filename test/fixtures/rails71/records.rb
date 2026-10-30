# frozen_string_literal: true

module Rails71Fixture
  CONDITION = ->(*) { raise 'condition executed' }
  class Parent < ActiveRecord::Base
    self.abstract_class = true
    before_save :stamp, if: :allowed?
    def stamp = raise('parent callback executed')
    def allowed? = raise('condition method executed')
  end

  class Order < Parent
    self.table_name = 'thistle_rails71_orders'
    attribute :state, :string, default: -> { raise 'Ruby attribute default executed' }
    has_many :items, -> { raise 'association scope executed' }, class_name: 'Rails71Fixture::Item', foreign_key: :order_id
    before_save :local_stamp, unless: CONDITION
    def stamp = raise('effective child callback executed')
    def local_stamp = raise('local callback executed')
  end

  class PriorityOrder < Order; end
  class Item < ActiveRecord::Base
    self.table_name = 'thistle_rails71_items'
    belongs_to :order, class_name: 'Rails71Fixture::Order', optional: true
  end
  class Missing < ActiveRecord::Base
    self.table_name = 'thistle_rails71_missing'
    has_many :items, class_name: 'Rails71Fixture::Item'
  end

  class RouteGuard
    def matches?(*) = raise('route object executed')
    def inspect = raise('route object inspected')
    def to_s = raise('route object stringified')
  end
end
