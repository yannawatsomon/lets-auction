# lot_results reached main (#35, PR #96) a few minutes before the change that removed it was
# pushed. The team adds no new tables for now (docs/decision/bidding.md), and rankings are
# computed from bids (AuctionLot#results), so the table goes. One-off exception to "no new
# migrations", approved by @guy127 on 2026-11-11. Nothing reads or writes it after this change.
class DropLotResults < ActiveRecord::Migration[8.1]
  def up
    drop_table :lot_results
  end

  def down
    create_table :lot_results do |t|
      t.references :lot, null: false, foreign_key: { to_table: :auction_lots }
      t.references :bid, null: false, foreign_key: true, index: { unique: true }
      t.bigint :user_id, null: false
      t.integer :rank, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :offered_at
      t.timestamps

      t.check_constraint "rank >= 1", name: "lot_results_rank_positive"
      t.check_constraint "status IN ('pending', 'offered', 'paid', 'expired', 'declined')", name: "lot_results_status_valid"
    end
    add_index :lot_results, [ :lot_id, :rank ], unique: true
    add_index :lot_results, [ :lot_id, :user_id ], unique: true
  end
end
