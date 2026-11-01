class ApplicationController < ActionController::Base
  before_action :authenticate

  def authenticate
    raise 'Observation must never run a filter'
  end
end
