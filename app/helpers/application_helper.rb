module ApplicationHelper
  def baht(satang) = "฿ #{Baht.format(satang)}"
end
