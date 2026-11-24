module Bidding
  # Results after an auction closes (#36). Admins check the ranking, may take a bidder out
  # (with a reason), and approve; approval offers each lot to rank 1 for 48 hours. If they
  # decline or don't pay, the next rank is offered the lot at their own bid, and so on; when
  # nobody is left the lot is unsold and the product goes back to approved (bidding.md).
  # Offers/orders are mock data (OrderStore); every step is audit-logged.
  module Results
    module_function

    def disqualify!(lot:, user_id:, reason:, admin:, now: Time.current)
      auction = lot.auction
      raise Error.new("not_awaiting_approval", "ตัดสิทธิ์ได้เฉพาะก่อนอนุมัติผล", :conflict) unless auction.awaiting_approval?
      reason = reason.to_s.strip
      raise Error.new("reason_required", "ต้องระบุเหตุผลการตัดสิทธิ์", :unprocessable_content) if reason.empty?
      raise Error.new("reason_too_long", "เหตุผลยาวเกิน 500 ตัวอักษร", :unprocessable_content) if reason.length > 500
      unless lot.results.any? { |r| r.user_id == user_id.to_i }
        raise Error.new("not_a_bidder", "ผู้ใช้นี้ไม่ได้เสนอราคาในล็อตนี้", :unprocessable_content)
      end

      OrderStore.disqualify!(lot.id, user_id.to_i, reason)
      AuditLog.record!(action: "result.disqualified", entity: lot, actor: admin,
        data: { user_id: user_id.to_i, reason:, at: now.iso8601(3) })
    end

    def approve!(auction:, admin:, now: Time.current)
      offers = []
      auction.with_lock do
        raise Error.new("not_awaiting_approval", "อนุมัติผลได้เฉพาะงานที่ปิดแล้วและรอประกาศผล", :conflict) unless auction.awaiting_approval?

        auction.lots.where(status: "closed").find_each do |lot|
          order = OrderStore.offer_next!(lot, now:)
          order ? offers << order : leave_unsold(lot, now)
        end
        auction.update_columns(status: "published", updated_at: now)
        AuditLog.record!(action: "auction.results_approved", entity: auction, actor: admin,
          data: { at: now.iso8601(3), offers: offers.map { |o| { lot_id: o.lot_id, rank: o.rank, buyer_id: o.buyer_id } } })
      end
      offers.each { |o| OrderExpireJob.set(wait_until: o.payment_due_at).perform_later(o.id) }
      Broadcaster.result_published(auction)
      offers
    end

    # Buyer gives up the lot.
    def decline!(order_id:, buyer:, now: Time.current)
      order = OrderStore.find(order_id)
      raise Error.new("not_found", "ไม่พบรายการนี้", :not_found) unless order && order.buyer_id == buyer&.id
      raise Error.new("not_awaiting_payment", "รายการนี้ไม่ได้รอชำระแล้ว", :conflict) unless OrderStore.close!(order.id, "declined", now:)

      AuditLog.record!(action: "order.declined", entity: order.lot, actor: buyer, data: { order_id: order.id, rank: order.rank })
      offer_next(order.lot, now)
    end

    # Deadline passed (OrderExpireJob or the sweep). Does nothing before the deadline.
    def expire!(order_id:, now: Time.current)
      order = OrderStore.find(order_id)
      return unless order&.due?(now)
      return unless OrderStore.close!(order.id, "expired", now:)

      AuditLog.record!(action: "order.expired", entity: order.lot, data: { order_id: order.id, rank: order.rank })
      offer_next(order.lot, now)
    end

    # MOCK until the payment milestone records real payments: an admin marks the order paid.
    def mark_paid!(order_id:, admin:, now: Time.current)
      order = OrderStore.find(order_id)
      raise Error.new("not_found", "ไม่พบรายการนี้", :not_found) unless order
      raise Error.new("not_awaiting_payment", "รายการนี้ไม่ได้รอชำระแล้ว", :conflict) unless OrderStore.close!(order.id, "paid", now:)

      lot = order.lot
      lot.update_columns(status: "sold", updated_at: now)
      AuctionItems.mark_sold!(lot.item)
      AuditLog.record!(action: "order.paid", entity: lot, actor: admin, data: { order_id: order.id, rank: order.rank })
    end

    def offer_next(lot, now)
      order = OrderStore.offer_next!(lot, now:)
      if order
        AuditLog.record!(action: "order.offered", entity: lot, data: { order_id: order.id, rank: order.rank, buyer_id: order.buyer_id })
        OrderExpireJob.set(wait_until: order.payment_due_at).perform_later(order.id)
      else
        leave_unsold(lot, now)
      end
      order
    end

    def leave_unsold(lot, now)
      lot.update_columns(status: "unsold", updated_at: now)
      AuctionItems.release!(lot.item)
      AuditLog.record!(action: "lot.unsold", entity: lot, data: { at: now.iso8601(3) })
    end
  end
end
