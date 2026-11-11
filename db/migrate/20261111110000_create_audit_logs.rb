# Shared, append-only audit trail (design draft `audit_logs`; first used by bidding #31).
# Plain text: never put secrets in `data` (e.g. sealed bid amounts, national IDs) — store ids.
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      # MOCK: users table not on main yet, so no foreign key (ai/knowledge/mock-data.md).
      t.bigint :actor_id
      t.string :action, null: false        # e.g. "bid.placed", "auction.scheduled"
      t.string :entity_type, null: false   # e.g. "Bid"
      t.bigint :entity_id, null: false
      t.json :data, null: false, default: {}
      t.datetime :created_at, null: false, precision: 6
    end
    add_index :audit_logs, [ :entity_type, :entity_id ]
    add_index :audit_logs, [ :action, :created_at ]
  end
end
