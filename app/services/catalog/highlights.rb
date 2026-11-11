module Catalog
  class Highlights
    Entry = Data.define(:lot, :status)

    def self.call(sections:)
      sections.fetch(:ongoing, []).filter_map do |lot|
        price = lot.min_price_cents
        Entry.new(lot, :ongoing) if price.is_a?(Integer) && price.positive?
      end.sort_by { |entry| [ -entry.lot.min_price_cents, entry.lot.id ] }
        .uniq { |entry| entry.lot.id }.first(5)
    end
  end
end
