# Shared, append-only audit trail. Any milestone may write to it with `AuditLog.record!`.
# Rows can't be changed or deleted. `data` is stored in plain text: put ids and public facts
# in it, never secrets (sealed bid amounts, national IDs, slips). See ai/knowledge/bidding-bids.md.
class AuditLog < ApplicationRecord
  class AppendOnly < StandardError; end

  validates :action, :entity_type, :entity_id, presence: true
  before_update { raise AppendOnly, "audit logs can't be changed" }
  before_destroy { raise AppendOnly, "audit logs can't be deleted" }

  def readonly? = persisted? || super

  def self.record!(action:, entity:, actor: nil, data: {})
    create!(action:, entity_type: entity.class.name, entity_id: entity.id, actor_id: actor&.id, data:)
  end
end
