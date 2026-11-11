class CreateAuctionLots < ActiveRecord::Migration[8.1]
  def change
    create_table :auction_lots do |t|
      t.references :auction, null: false, foreign_key: true
      # MOCK: items table not on main yet, so no foreign key (ai/knowledge/mock-data.md).
      t.bigint :item_id, null: false
      t.integer :lot_no, null: false
      t.bigint :min_price_cents, null: false         # snapshot of the item's minimum price
      t.bigint :bid_increment_cents                  # English only
      t.bigint :current_price_cents                  # English only
      t.bigint :leader_bid_id                        # English only; FK added with bids (#30)
      t.datetime :ends_at, null: false               # English lots can be extended one by one
      t.datetime :original_ends_at, null: false      # base for the 30-minute extension cap
      t.string :status, null: false, default: "scheduled"
      t.integer :bid_count, null: false, default: 0
      t.timestamps

      t.check_constraint "lot_no BETWEEN 1 AND 10", name: "auction_lots_max_ten"
      t.check_constraint "min_price_cents > 0", name: "auction_lots_min_price_positive"
      t.check_constraint "bid_increment_cents IS NULL OR bid_increment_cents > 0", name: "auction_lots_increment_positive"
      t.check_constraint "status IN ('scheduled', 'live', 'closed', 'sold', 'unsold', 'cancelled')", name: "auction_lots_status_valid"
    end
    add_index :auction_lots, [ :auction_id, :lot_no ], unique: true
    add_index :auction_lots, [ :auction_id, :item_id ], unique: true
    # An item can be in only one lot that hasn't finished.
    add_index :auction_lots, :item_id, unique: true, name: "one_open_lot_per_item",
      where: "status IN ('scheduled', 'live', 'closed')"
  end
end
