# frozen_string_literal: true

# These two reads deliberately name the same target at distinct source sites.
# Capturing does not call this method or claim runtime constant binding.
class Inspection
  def sites
    accept(Order)
    value = Order
    value
  end

  def accept(value) = value
end
