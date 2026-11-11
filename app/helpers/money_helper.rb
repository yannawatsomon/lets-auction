# Shared by every milestone (product onboarding uses it). Money is satang, see Baht.
module MoneyHelper
  def baht(cents) = "฿ #{Baht.format(cents)}"
end
