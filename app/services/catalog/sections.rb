module Catalog
  # Callers supply visible lots and their latest effective closing times.
  # This service does not authorize access or load records from the database.
  class Sections
    def self.call(lots:, now:)
      raise ArgumentError, "now must be a timestamp" unless now.is_a?(Time)

      groups = { ongoing: [], upcoming: [], ended: [] }
      ids = Set.new

      lots.each do |lot|
        validate_lot!(lot, ids)

        status = if now < lot.starts_at
          :upcoming
        elsif now < lot.ends_at
          :ongoing
        else
          :ended
        end
        groups.fetch(status) << lot
      end

      groups[:ongoing].sort_by! { |lot| [ lot.ends_at.to_r, lot.id ] }
      groups[:upcoming].sort_by! { |lot| [ lot.starts_at.to_r, lot.id ] }
      groups[:ended].sort_by! { |lot| [ -lot.ends_at.to_r, lot.id ] }
      groups
    end

    def self.validate_lot!(lot, ids)
      unless lot.respond_to?(:id) && lot.respond_to?(:starts_at) && lot.respond_to?(:ends_at)
        raise ArgumentError, "lots must provide id, starts_at, and ends_at"
      end
      unless lot.id.is_a?(Integer) && ids.add?(lot.id)
        raise ArgumentError, "lot IDs must be unique integers"
      end
      unless lot.starts_at.is_a?(Time) && lot.ends_at.is_a?(Time) && lot.starts_at < lot.ends_at
        raise ArgumentError, "lot timestamps must be present with start before close"
      end
    end
    private_class_method :validate_lot!
  end
end
