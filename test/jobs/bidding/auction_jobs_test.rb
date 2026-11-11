require "test_helper"

class Bidding::AuctionJobsTest < ActiveJob::TestCase
  setup do
    ProductOnboarding::Store.reset!
    @a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @a.add_item!(MockData.approved_items.min_by(&:min_price_cents))
  end

  test "scheduling enqueues the open and close jobs at the auction's times" do
    @a.schedule!
    assert_enqueued_with(job: Bidding::AuctionOpenJob, args: [ @a.id ], at: @a.starts_at)
    assert_enqueued_with(job: Bidding::AuctionCloseJob, args: [ @a.id ], at: @a.ends_at)
  end

  test "open job: early run waits again; on time it opens" do
    @a.schedule!
    clear_enqueued_jobs
    travel_to(@a.starts_at - 5.minutes) do
      Bidding::AuctionOpenJob.perform_now(@a.id)
      assert @a.reload.scheduled?
      assert_enqueued_with(job: Bidding::AuctionOpenJob, args: [ @a.id ], at: @a.starts_at)
    end
    travel_to(@a.starts_at + 1.second) { Bidding::AuctionOpenJob.perform_now(@a.id) }
    assert @a.reload.live?
  end

  test "close job: early run waits again; on time it closes" do
    @a.schedule!
    clear_enqueued_jobs
    travel_to(@a.ends_at - 1.minute) do
      Bidding::AuctionCloseJob.perform_now(@a.id)
      assert @a.reload.scheduled?
      assert_enqueued_with(job: Bidding::AuctionCloseJob, args: [ @a.id ], at: @a.ends_at)
    end
    travel_to(@a.ends_at + 1.second) { Bidding::AuctionCloseJob.perform_now(@a.id) }
    assert @a.reload.awaiting_approval?
  end

  test "jobs for a cancelled or deleted auction do nothing" do
    @a.schedule!
    @a.cancel!(reason: "x")
    travel_to(@a.ends_at + 1.second) do
      Bidding::AuctionOpenJob.perform_now(@a.id)
      Bidding::AuctionCloseJob.perform_now(@a.id)
      Bidding::AuctionCloseJob.perform_now(0)
    end
    assert @a.reload.cancelled?
  end

  test "the sweep opens and closes whatever is due" do
    @a.schedule!
    Bidding::AuctionSweepJob.perform_now(now: @a.starts_at + 1.second)
    assert @a.reload.live?
    Bidding::AuctionSweepJob.perform_now(now: @a.ends_at + 1.second)
    assert @a.reload.awaiting_approval?
  end

  test "the sweep is registered as a recurring job" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    assert_equal "Bidding::AuctionSweepJob", recurring.dig("production", "bidding_auction_sweep", "class")
  end
end
