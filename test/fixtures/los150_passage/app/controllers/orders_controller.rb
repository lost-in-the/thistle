class OrdersController < ApplicationController
  before_action :check_order, only: :create
  after_action :audit_order, except: :index, if: -> { raise 'Never evaluate a condition' }

  def create
    order = ::Order.create!(name: 'saved_a')
    ::ReceiptJob.perform_later(order.id)
    ::ReceiptMailer.receipt(order.id).deliver_later
  end

  def index
    ::Order.all
    :saved_a
  end

  def preview
    order_helper.prepare.save!
  end

  def conditional
    ::Order.create!(name: 'conditional') if allowed_to_save?
  end

  def show
    :first_definition
  end

  def show
    :second_definition
  end

  def check_order
    raise 'Observation must never run check_order'
  end

  def audit_order
    raise 'Observation must never run audit_order'
  end
end
