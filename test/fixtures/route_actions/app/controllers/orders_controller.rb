class OrdersController < ApplicationController
  def index
    :saved_a
  end

  def show
    :first_definition
  end

  def self.class_only
    :not_an_action_candidate
  end
end
