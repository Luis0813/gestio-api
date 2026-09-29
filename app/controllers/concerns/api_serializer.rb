# == Central JSON serialization layer for the API
#
# Rails serializes `decimal` columns as JSON strings by default ("12.50"), and
# the frontend performs arithmetic such as `amount.toFixed(2)`, which breaks on
# strings. `ApiSerializer.dump` normalizes every payload so that:
#
# * BigDecimal / ActiveSupport::DecimalWithMetadata -> Float  (JSON number)
# * Date                                         -> "YYYY-MM-DD"
# * Time / ActiveSupport::TimeWithZone            -> ISO8601
# * nil, String, Integer, Float, booleans, Array and Hash (jsonb) are untouched
#
# `ActiveRecord::Relation` (the object returned by `Model.all` / `scope.order`)
# is normalized into an Array first. Without this branch the relation would fall
# through to the `else` clause, be returned untouched, and Rails would later
# render it with its own `as_json`, which re-encodes every decimal as a JSON
# string ("3.0") and breaks the frontend's `value.toFixed(2)` calls.
#
# ActiveRecord objects are read through `attributes` (instead of `as_json`) on
# purpose: `as_json` runs the values through ActiveSupport's encoders, which
# would turn decimals into strings before this module ever sees them.
module ApiSerializer
  class << self
    # Converts an ActiveRecord object, an Array of them, or any nested
    # structure into JSON-ready primitives.
    def dump(value)
      normalize(value)
    end

    private

    def normalize(value)
      case value
      when BigDecimal
        value.to_f
      when DateTime, Time, ActiveSupport::TimeWithZone
        value.iso8601
      when Date
        value.strftime("%Y-%m-%d")
      when Symbol
        value.to_s
      when Array
        value.map { |item| normalize(item) }
      when ActiveRecord::Relation
        normalize(value.to_a)
      when Hash
        value.to_h { |key, item| [ key, normalize(item) ] }
      when ActiveRecord::Base
        normalize(value.attributes)
      else
        decimal_with_metadata?(value) ? value.to_d.to_f : value
      end
    end

    # `ActiveSupport::DecimalWithMetadata` only exists in newer Rails versions,
    # so it is detected dynamically instead of being referenced at load time.
    def decimal_with_metadata?(value)
      defined?(ActiveSupport::DecimalWithMetadata) && value.is_a?(ActiveSupport::DecimalWithMetadata)
    end
  end

  # Instance-level shortcut so controllers can call `serialize(record)`.
  def serialize(value)
    ApiSerializer.dump(value)
  end
end
