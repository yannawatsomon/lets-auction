class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :items, dependent: :restrict_with_exception

  validates :name, presence: true
end
