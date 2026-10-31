# frozen_string_literal: true

class OrdersController < ActionController::Base
  def show
    order = Order.find(params.fetch(:id))
    render json: { reference: order.reference, quantities: order.items.order(:id).pluck(:quantity) }
  end

  def health
    render json: { fixture: 'reusable-host-v1', peer: request.get_header('REMOTE_ADDR'), host: request.host }
  end
end
