# View helpers for the bidding milestone. Rails shares helpers across all views, so every
# method starts with `bidding_` to avoid clashing with other milestones (e.g. CatalogHelper).
module BiddingHelper
  STATUS_LABELS = {
    "draft" => "Draft", "scheduled" => "Scheduled", "live" => "Live",
    "awaiting_approval" => "Awaiting results", "published" => "Results published", "cancelled" => "Cancelled"
  }.freeze
  TYPE_LABELS = { "sealed_first_price" => "Sealed bid", "english" => "English (invite only)" }.freeze
  PARTICIPANT_LABELS = { "registered" => "Registered", "invited" => "Invited", "accepted" => "Accepted", "revoked" => "Revoked" }.freeze

  # Lucide icons (https://lucide.dev, ISC license), inner SVG only. Add a path from lucide.dev
  # when you need a new one; never use emoji as icons (ai/knowledge/ui-design.md).
  ICONS = {
    arrow_left: '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
    arrow_right: '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    lock: '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    shield_check: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    alert: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    circle_check: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    gavel: '<path d="m14.5 12.5-8 8a2.119 2.119 0 1 1-3-3l8-8"/><path d="m16 16 6-6"/><path d="m8 8 6-6"/><path d="m9 7 8 8"/><path d="m21 11-8-8"/>',
    image: '<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>',
    log_out: '<path d="m16 17 5-5-5-5"/><path d="M21 12H9"/><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>',
    user_plus: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6"/><path d="M22 11h-6"/>'
  }.freeze
  NOTICE_ICONS = { ok: :circle_check, warn: :alert, notice: :circle_check, alert: :alert }.freeze

  # Decorative by default (aria-hidden); the text next to it carries the meaning.
  def bidding_icon(name, size: 16)
    tag.svg(ICONS.fetch(name).html_safe, class: "bidding-icon", width: size, height: size, viewBox: "0 0 24 24", # rubocop:disable Rails/OutputSafety -- constant markup above
            fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round",
            "aria-hidden": "true", focusable: "false")
  end

  def bidding_status_chip(auction)
    label = STATUS_LABELS.fetch(auction.status)
    tag.span(class: [ "bidding-chip", "bidding-chip--#{auction.status}" ]) do
      auction.live? ? safe_join([ tag.span(class: "bidding-dot", "aria-hidden": "true"), label ]) : label
    end
  end

  def bidding_type_label(auction_or_type)
    type = auction_or_type.respond_to?(:auction_type) ? auction_or_type.auction_type : auction_or_type
    TYPE_LABELS.fetch(type.to_s)
  end

  def bidding_baht(cents) = baht(cents)

  # 15 Nov 2026, 18:00 (Asia/Bangkok)
  def bidding_time(time)
    return "—" unless time

    time.in_time_zone.strftime("%-d %b %Y, %H:%M")
  end

  def bidding_datetime_field_value(time)
    time&.in_time_zone&.strftime("%Y-%m-%dT%H:%M")
  end
end
