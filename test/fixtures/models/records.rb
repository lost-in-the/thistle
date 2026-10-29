# frozen_string_literal: true

module ModelFixture
  class Order < ActiveRecord::Base
    self.table_name = 'orders'
    has_many :items, -> { raise 'association scope executed' }, class_name: 'ModelFixture::Item'
    has_many :payments, class_name: 'ModelFixture::Payment'
    has_many :products, through: :items
    attribute :custom, :string, default: -> { raise 'attribute default executed' }
    default_scope { raise 'default scope executed' }
    scope :danger, -> { raise 'named scope executed' }
    after_initialize { raise 'application callback executed' }
    def self.business_method = raise('business method executed')
    def self.column_defaults = raise('effective defaults read')
    def self.columns = raise('model attribute schema read')
  end
  class PriorityOrder < Order; end
  class Item < ActiveRecord::Base
    self.table_name = 'items'
    belongs_to :order, class_name: 'ModelFixture::Order'
    belongs_to :product, class_name: 'ModelFixture::Product'
  end
  class Payment < ActiveRecord::Base
    self.table_name = 'payments'
    belongs_to :order, class_name: 'ModelFixture::Order'
    belongs_to :subject, polymorphic: true
  end
  class Product < ActiveRecord::Base
    self.table_name = 'products'
  end
  class MissingTable < ActiveRecord::Base
    self.table_name = 'not_present'
    has_many :ghosts, class_name: 'NotLoadedGhost'
  end
end
