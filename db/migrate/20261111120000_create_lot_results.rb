# Ranking of every bidder on a closed lot (issue #35), written once by the close job.
# No amount column: the amount stays encrypted in `bids`; read it through `bid`.
class CreateLotResults < ActiveRecord::Migration[8.1]
  def change
    create_table :lot_results do |t|
      t.references :lot, null: false, foreign_key: { to_table: :auction_lots }
      t.references :bid, null: false, foreign_key: true, index: { unique: true }
      # MOCK: users table not on main yet, so no foreign key (ai/knowledge/mock-data.md).
      t.bigint :user_id, null: false
      t.integer :rank, null: false
      # pending → offered → paid | expired | declined (#36 and payment move it)
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
