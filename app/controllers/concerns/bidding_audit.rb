# Writes bidding actions to the shared audit log (#37, bidding.md: admins do all checking, so
# every admin action is recorded with who, what and when). Data is plain text: ids, statuses and
# reasons only, never bid amounts.
module BiddingAudit
  extend ActiveSupport::Concern

  private

  def audit!(action, entity, data = {})
    AuditLog.record!(action:, entity:, actor: current_user, data:)
  end
end
