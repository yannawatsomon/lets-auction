# Bids (issue #30, docs/decision/bidding.md). Append-only: the model refuses update/destroy;
# on Postgres the app's role also gets no UPDATE/DELETE on this table (see knowledge note).
class CreateBids < ActiveRecord::Migration[8.1]
  def change
    create_table :bids do |t|
      t.references :lot, null: false, index: false, foreign_key: { to_table: :auction_lots }
      # MOCK: users table not on main yet, so no foreign key (ai/knowledge/mock-data.md).
      t.bigint :user_id, null: false
      # Copied from the auction so the sealed-only unique index below can use it.
      t.string :auction_type, null: false
      # Active Record Encryption ciphertext of the amount in satang (Decided: one text column,
      # encrypted for both types). No SQL sort/index/CHECK on it; ranking happens in Ruby.
      t.text :amount_cents, null: false
      t.string :idempotency_key, null: false
      # Rails writes microsecond server time; ties go to the earliest (then lowest id).
      t.datetime :created_at, null: false, precision: 6

      t.check_constraint "auction_type IN ('sealed_first_price', 'english')", name: "bids_type_valid"
      t.check_constraint "length(idempotency_key) BETWEEN 1 AND 200", name: "bids_idempotency_key_length"
    end
    add_index :bids, [ :user_id, :idempotency_key ], unique: true
    # Sealed: one bid per buyer per lot, enforced by the database.
    add_index :bids, [ :lot_id, :user_id ], unique: true, name: "one_sealed_bid_per_user",
      where: "auction_type = 'sealed_first_price'"
    add_index :bids, [ :lot_id, :created_at ]

    add_foreign_key :auction_lots, :bids, column: :leader_bid_id
    add_index :auction_lots, :leader_bid_id
  end
end
