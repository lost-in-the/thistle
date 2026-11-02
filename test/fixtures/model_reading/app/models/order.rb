# frozen_string_literal: true
class Order < ApplicationRecord
  include ReceiptPolicy
  belongs_to :user, optional: true
  has_many :line_items, dependent: :destroy
  after_save :schedule_receipt, if: :receipt_due?

  def receipt_due?
    receipt_enabled && user_id.present?
  end

  def receipt_marker
    'saved_a'
  end

  # Named no-op registrations exercise recovery beyond the compact first8.
  # None of these methods or conditions is executed by the producer.
  def receipt_context = receipt_state
  def receipt_recipient = user_id
  def receipt_items = line_items
  def receipt_switch = receipt_enabled
  def receipt_primary_key = id
  def receipt_model_name = self.class.name
  def receipt_delivery_policy = 'pending'
  def zz_receipt_witness = 'retained_method_suffix'

  after_save :receipt_context, :receipt_recipient, :receipt_items, :receipt_switch,
    :receipt_primary_key, :receipt_model_name, :receipt_delivery_policy, :zz_receipt_witness
end
