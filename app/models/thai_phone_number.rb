# Thai mobile number: 10 digits starting 06, 08 or 09. Stored as +66XXXXXXXXX.
class ThaiPhoneNumber
  LOCAL = /\A0[689]\d{8}\z/

  # Returns "+66812345678" or nil when the input is not a valid Thai mobile number.
  def self.normalize(value)
    cleaned = value.to_s.gsub(/[\s-]/, "")
    local = cleaned.sub(/\A\+?66/, "0")
    local.match?(LOCAL) ? "+66#{local[1..]}" : nil
  end

  def self.valid?(value)
    !normalize(value).nil?
  end
end
