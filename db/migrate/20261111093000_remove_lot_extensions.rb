# English lots no longer extend (docs/decision/bidding.md, 2026-11-11): every lot ends at the
# auction's ends_at, so the per-lot end times and extension settings go.
class RemoveLotExtensions < ActiveRecord::Migration[8.1]
  def change
    remove_column :auctions, :extension_window_sec, :integer, null: false, default: 120
    remove_column :auctions, :extension_sec, :integer, null: false, default: 120
    remove_column :auctions, :extension_cap_sec, :integer, null: false, default: 1800
    remove_column :auction_lots, :ends_at, :datetime
    remove_column :auction_lots, :original_ends_at, :datetime
  end
end
