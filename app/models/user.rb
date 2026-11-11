# Placeholder account model. Product onboarding only needs a seller to own an item and an
# admin to review it. The user-onboarding milestone (#16) owns the real model; replace this
# file with theirs and keep `role` (buyer, seller, admin) and `items` working.
class User < ApplicationRecord
  enum :role, { buyer: "buyer", seller: "seller", admin: "admin" }, validate: true

  has_many :items, foreign_key: :seller_id, inverse_of: :seller, dependent: :restrict_with_exception

  validates :email, presence: true, uniqueness: true
end
