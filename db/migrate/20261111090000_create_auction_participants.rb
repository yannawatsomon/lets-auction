class CreateAuctionParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :auction_participants do |t|
      t.references :auction, null: false, foreign_key: true
      # MOCK: users table not on main yet, so no foreign keys (ai/knowledge/mock-data.md).
      t.bigint :user_id, null: false
      t.string :source, null: false                 # registered (sealed) | invited (English)
      t.string :status, null: false                 # registered | invited | accepted | revoked
      t.bigint :invited_by_id
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.bigint :revoked_by_id
      # Snapshot of the grade checked at registration/invite (checked once, not per bid).
      t.string :grade_at_entry, null: false
      t.timestamps

      t.check_constraint "source IN ('registered', 'invited')", name: "participants_source_valid"
      t.check_constraint "status IN ('registered', 'invited', 'accepted', 'revoked')", name: "participants_status_valid"
      t.check_constraint "(source = 'registered' AND status IN ('registered', 'revoked')) OR " \
                         "(source = 'invited' AND status IN ('invited', 'accepted', 'revoked'))",
        name: "participants_status_matches_source"
      t.check_constraint "source <> 'invited' OR invited_by_id IS NOT NULL", name: "participants_invite_has_inviter"
    end
    add_index :auction_participants, [ :auction_id, :user_id ], unique: true
    add_index :auction_participants, [ :user_id, :status ]
  end
end
