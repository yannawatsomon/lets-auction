class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      # Money is an integer number of satang (docs/decision/bidding.md, proposed).
      t.bigint :min_price_cents, null: false
      t.string :status, null: false, default: "pending_review"
      t.string :contact_channel
      # Optimistic locking: lets an admin's decision be refused if the seller edited meanwhile.
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :items, [ :status, :category_id ]
    add_index :items, [ :seller_id, :status ]
    add_check_constraint :items, "min_price_cents > 0", name: "items_min_price_positive"
    add_check_constraint :items,
      "status IN ('pending_review', 'info_requested', 'approved', 'rejected', 'in_auction', 'sold', 'withdrawn')",
      name: "items_status_valid"
  end
end
