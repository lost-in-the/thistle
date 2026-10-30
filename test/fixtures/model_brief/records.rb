# frozen_string_literal: true
module BriefFixture
  class DeliveryJob
    def self.perform_later(*) = raise('request executed')
  end
  class Parent < ActiveRecord::Base
    self.abstract_class = true
    before_save :deliver
    def deliver
      BriefFixture::DeliveryJob.perform_later("雪\n\"quoted\"")
      raise 'callback executed'
    end
  end
  class Order < Parent
    self.table_name = 'orders'
    has_many :items, class_name: 'BriefFixture::Item'
    before_save -> { raise 'opaque callback executed' }
  end
  class Item < ActiveRecord::Base
    self.table_name = 'items'
    belongs_to :order, class_name: 'BriefFixture::Order'
  end
end
