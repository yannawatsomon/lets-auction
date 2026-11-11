module Catalog
  # Filters caller-authorized lots; this class does not load or authorize records.
  class Filters
    include ActiveModel::Model

    FIELDS = %i[q category status auction_type date_field from to].freeze
    STATUSES = %w[ongoing upcoming ended].freeze
    TYPES = %w[english sealed_first_price].freeze
    DATE_FIELDS = %w[starts_at ends_at].freeze
    LOCAL_TIMESTAMP = /\A(\d{4})-(\d{2})-(\d{2})T([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\z/

    attr_reader(*FIELDS)
    validate :validate_inputs

    def initialize(attributes = {}, categories:)
      @categories = categories
      @invalid_fields = []
      attributes = attributes.symbolize_keys
      FIELDS.each do |field|
        value = attributes[field]
        @invalid_fields << field unless value.nil? || value.is_a?(String)
        instance_variable_set("@#{field}", value.is_a?(String) ? value.strip : "")
      end
      @date_field = "starts_at" if @date_field.empty?
    end

    def sections(lots:, now:)
      groups = { ongoing: [], upcoming: [], ended: [] }
      if valid?
        matches = lots.select do |lot|
          lot.name.downcase.include?(q.downcase) &&
            (category.empty? || lot.category == category) &&
            (auction_type.empty? || lot.auction_type == auction_type) &&
            (@from_time.nil? || lot.public_send(date_field) >= @from_time) &&
            (@to_time.nil? || lot.public_send(date_field) <= @to_time)
        end
        groups = Sections.call(lots: matches, now: now)
      end
      STATUSES.include?(status) ? groups.slice(status.to_sym) : groups
    end

    private

    def validate_inputs
      @invalid_fields.each { |field| errors.add(field, "กรุณาระบุค่าเดียว") }
      FIELDS.each do |field|
        errors.add(field, "ยาวเกินกำหนด (สูงสุด 100 ตัวอักษร)") if public_send(field).length > 100
      end
      validate_choice(:category, @categories, allow_blank: true)
      validate_choice(:status, STATUSES, allow_blank: true)
      validate_choice(:auction_type, TYPES, allow_blank: true)
      validate_choice(:date_field, DATE_FIELDS)
      @from_time = parse_timestamp(:from)
      @to_time = parse_timestamp(:to)
      if @from_time && @to_time && @from_time > @to_time
        errors.add(:to, "วันเวลาสิ้นสุดต้องไม่ก่อนวันเวลาเริ่มต้น")
      end
    end

    def validate_choice(field, choices, allow_blank: false)
      value = public_send(field)
      return if (allow_blank && value.empty?) || choices.include?(value)

      errors.add(field, "กรุณาเลือกค่าที่มีในรายการ")
    end

    def parse_timestamp(field)
      value = public_send(field)
      return if value.empty?

      parts = LOCAL_TIMESTAMP.match(value)
      if parts && Date.valid_date?(*parts.captures.first(3).map(&:to_i))
        timestamp = value.length == 16 ? "#{value}:00" : value
        return Time.iso8601("#{timestamp}+07:00")
      end
      errors.add(field, "กรุณาระบุวันเวลาไทยที่ถูกต้อง")
      nil
    end
  end
end
