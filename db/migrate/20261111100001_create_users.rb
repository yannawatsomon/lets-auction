# Placeholder account table so items can reference a seller and an admin.
# The user-onboarding milestone (#16) owns the real users model: when it lands, replace this
# migration and model with theirs, keeping `role` (buyer, seller, admin).
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :role, null: false, default: "buyer"
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN ('buyer', 'seller', 'admin')", name: "users_role_valid"
  end
end
