# Thai national ID: 13 digits, last digit is a mod 11 check digit.
# Plain value object (no database). Never log or display the raw number; use .mask.
class ThaiNationalId
  LENGTH = 13

  def self.normalize(value)
    value.to_s.gsub(/[\s-]/, "")
  end

  def self.valid?(value)
    digits = normalize(value)
    return false unless digits.match?(/\A\d{#{LENGTH}}\z/)

    ints = digits.chars.map(&:to_i)
    sum = ints.first(12).each_with_index.sum { |d, i| d * (LENGTH - i) }
    ((11 - (sum % 11)) % 10) == ints.last
  end

  # "1-XXXX-XXXXX-XX-1" (first and last digit only)
  def self.mask(value)
    d = normalize(value)
    "#{d[0]}-XXXX-XXXXX-XX-#{d[12]}"
  end
end
