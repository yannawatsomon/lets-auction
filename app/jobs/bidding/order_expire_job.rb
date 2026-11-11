module Bidding
  # At an offer's 48-hour deadline (#36): if still unpaid, it expires and the next rank is
  # offered the lot. Orders are mock data, so after a restart there is nothing to expire.
  class OrderExpireJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      Results.expire!(order_id:)
    end
  end
end
