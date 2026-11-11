# Opt-in bidding demo on Railway (2026-11-11, docs/decision/bidding.md): the mock login offers
# every role (admin, buyer, seller) so the team can try the bidding pages on the real URL before
# real auth exists. It fails closed: on only when MOCK_BIDDING is exactly "true" AND
# MOCK_BIDDING_PASSWORD is at least 12 characters; visitors must type that password before they
# can pick a mock user. Production data is demo data while this is on. Remove with real auth.
demo_password = ENV["MOCK_BIDDING_PASSWORD"].to_s
Rails.application.config.x.mock_bidding = ENV["MOCK_BIDDING"] == "true" && demo_password.length >= 12
Rails.application.config.x.mock_bidding_password = demo_password
