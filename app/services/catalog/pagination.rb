module Catalog
  class Pagination
    include ActiveModel::Model

    PER_PAGE = 12
    MAX_PAGE = 100
    FIELDS = %i[ongoing_page upcoming_page ended_page].freeze

    validate :valid_counters

    def initialize(attributes = {})
      @invalid_fields = []
      @pages = FIELDS.to_h do |field|
        value = attributes[field]
        page = 1
        unless value.nil? || value == ""
          if value.is_a?(String) && value.match?(/\A[1-9]\d{0,2}\z/) && value.to_i <= MAX_PAGE
            page = value.to_i
          else
            @invalid_fields << field
          end
        end
        [ field, page ]
      end
    end

    def items(status, lots)
      lots.first(@pages.fetch(:"#{status}_page") * PER_PAGE)
    end

    def more?(status, lots)
      @pages.fetch(:"#{status}_page") < MAX_PAGE && items(status, lots).size < lots.size
    end

    def query
      @pages.transform_keys(&:to_s).transform_values(&:to_s)
    end

    def next_query(status)
      field = :"#{status}_page"
      query.merge(field.to_s => [ @pages.fetch(field) + 1, MAX_PAGE ].min.to_s)
    end

    private

    def valid_counters
      @invalid_fields.each { |field| errors.add(field, "กรุณาระบุหน้าระหว่าง 1 ถึง #{MAX_PAGE}") }
    end
  end
end
