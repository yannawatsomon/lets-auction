class CreateAuctions < ActiveRecord::Migration[8.1]
  def change
    create_table :auctions do |t|
      t.string :title, null: false
      t.text :description
      t.string :auction_type, null: false            # sealed_first_price | english
      t.string :visibility, null: false, default: "public" # public | invite_only
      t.string :status, null: false, default: "draft"
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # English anti-sniping (docs/decision/bidding.md): a bid with <= window left extends by
      # extension_sec, never past original end + cap.
      t.integer :extension_window_sec, null: false, default: 120
      t.integer :extension_sec, null: false, default: 120
      t.integer :extension_cap_sec, null: false, default: 1800
      # MOCK: users table not on main yet, so no foreign key (ai/knowledge/mock-data.md).
      t.bigint :created_by_id, null: false
      t.datetime :scheduled_at
      t.datetime :cancelled_at
      t.text :cancel_reason
      t.timestamps

      t.check_constraint "ends_at > starts_at", name: "auctions_ends_after_starts"
      t.check_constraint "auction_type IN ('sealed_first_price', 'english')", name: "auctions_type_valid"
      t.check_constraint "visibility IN ('public', 'invite_only')", name: "auctions_visibility_valid"
      t.check_constraint "auction_type <> 'english' OR visibility = 'invite_only'", name: "auctions_english_invite_only"
      t.check_constraint "status IN ('draft', 'scheduled', 'live', 'awaiting_approval', 'published', 'cancelled')", name: "auctions_status_valid"
      t.check_constraint "status <> 'cancelled' OR cancel_reason IS NOT NULL", name: "auctions_cancel_has_reason"
    end
    add_index :auctions, [ :status, :starts_at ]
  end
end
