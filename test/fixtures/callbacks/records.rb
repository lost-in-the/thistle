# frozen_string_literal: true

# Loaded explicitly by the fixture harness, never by the observer. No records,
# relations, database connection, or callback/condition bodies are needed.
module CallbackFixture
  class Opaque
    def before_save(*) = raise('callback object executed')
    def call(*) = raise('opaque condition executed')
    def inspect = raise('opaque inspected')
    def to_s = raise('opaque stringified')
    def to_json(*) = raise('opaque serialized')
  end
  OPAQUE = Opaque.new
  CONDITION = ->(*) { raise 'proc condition executed' }
  def CONDITION.source_location = raise('proc singleton source_location called')
  BODY = ->(*) { raise 'proc callback executed' }
  def BODY.source_location = raise('proc singleton source_location called')

  class Parent < ActiveRecord::Base
    self.abstract_class = true
    before_save :parent_stamp, if: :allowed?
    before_save :removed
    after_save :finished
    def parent_stamp = raise('parent body executed')
    def removed = raise('removed body executed')
    def finished = raise('after body executed')
    def allowed? = raise('symbol condition executed')
  end

  # This class is deliberately not an ActiveJob subclass. The syntax supports a
  # potential request only; no callback body, condition or job runs in capture.
  class DeliveryJob
    def self.perform_later(*) = raise('job request executed')
  end

  class Child < Parent
    skip_callback :save, :before, :removed
    before_save :first, prepend: true
    around_save :wrap, unless: CONDITION
    before_save BODY, if: [CONDITION, OPAQUE]
    before_save OPAQUE
    # Method implementation differs from the inherited registered filter.
    def parent_stamp
      raise 'effective override executed'
      CallbackFixture::DeliveryJob.perform_later if allowed?
    end
    def first = raise('prepended body executed')
    def wrap = raise('around body executed')
  end

  class ConditionalSkip < Parent
    skip_callback :save, :before, :parent_stamp, if: :skip_stamp?
    def skip_stamp? = raise('skip condition executed')
  end

  class Empty < ActiveRecord::Base
    self.abstract_class = true
  end
end
