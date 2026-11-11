# MOCK DATA: read-only stand-ins for `users` and `items` until auth / user onboarding and
# product onboarding land on `main`. Bidding code talks to these through `MockData.user` /
# `MockData.item`, so swapping in real models later is one place. See ai/knowledge/mock-data.md.
module MockData
  User = Data.define(:id, :role, :display_name) do
    def admin? = role == "admin"
    def seller? = role == "seller"
    def buyer? = role == "buyer"
  end

  Item = Data.define(:id, :seller_id, :category, :title, :min_price_cents, :status) do
    def approved? = status == "approved"
    def seller = MockData.user(seller_id)
  end

  class << self
    def users = @users ||= load("users", User)
    def items = @items ||= load("items", Item)

    def user(id) = users.find { |u| u.id == id.to_i }
    def item(id) = items.find { |i| i.id == id.to_i }
    def approved_items = items.select(&:approved?)

    private

    def load(name, klass)
      rows = YAML.load_file(Rails.root.join("db/mock/#{name}.yml"))
      rows.map { |row| klass.new(**row.transform_keys(&:to_sym)) }.freeze
    end
  end
end
