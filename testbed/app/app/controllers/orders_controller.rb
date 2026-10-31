# frozen_string_literal: true

class OrdersController < ActionController::Base
  def show
    order = Order.find(params.fetch(:id))
    render json: { reference: order.reference, quantities: order.items.order(:id).pluck(:quantity) }
  end

  def health
    render plain: 'reusable-host-v1'
  end
end
