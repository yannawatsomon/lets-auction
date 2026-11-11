class CreateItemReviews < ActiveRecord::Migration[8.1]
  def change
    # Append-only history of admin decisions: no updated_at, the model is read-only once saved.
    create_table :item_reviews do |t|
      t.references :item, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :note
      t.datetime :created_at, null: false
    end
    add_check_constraint :item_reviews, "action IN ('approve', 'reject', 'request_info')",
      name: "item_reviews_action_valid"
  end
end
