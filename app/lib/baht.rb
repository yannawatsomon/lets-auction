# Money is stored as an integer number of satang (docs/decision/bidding.md).
# Users type baht: "500" means 500.00 THB, "1,250.75" is allowed, more than two decimals is not.
module Baht
  FORMAT = /\A\d+(\.\d{1,2})?\z/

  module_function

  # Returns satang as Integer, or nil when the text is not a valid positive-or-zero amount.
  def parse(text)
    s = text.to_s.strip.delete(",")
    return nil unless FORMAT.match?(s)

    whole, frac = s.split(".")
    whole.to_i * 100 + (frac || "0").ljust(2, "0").to_i
  end

  # 125075 -> "1,250.75"
  def format(cents)
    return "" if cents.nil?

    whole, frac = cents.to_i.divmod(100)
    "#{whole.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ',')}.#{frac.to_s.rjust(2, '0')}"
  end
end
