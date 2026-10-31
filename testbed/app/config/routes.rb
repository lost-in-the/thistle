# frozen_string_literal: true

Rails.application.routes.draw do
  get '/orders/:id', to: 'orders#show', as: :order
  get '/health', to: 'orders#health'
end
