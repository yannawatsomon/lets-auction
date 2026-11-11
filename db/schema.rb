# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_100000) do
  create_table "auction_lots", force: :cascade do |t|
    t.integer "auction_id", null: false
    t.bigint "item_id", null: false
    t.integer "lot_no", null: false
    t.bigint "min_price_cents", null: false
    t.bigint "bid_increment_cents"
    t.bigint "current_price_cents"
    t.bigint "leader_bid_id"
    t.string "status", default: "scheduled", null: false
    t.integer "bid_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_id", "item_id"], name: "index_auction_lots_on_auction_id_and_item_id", unique: true
    t.index ["auction_id", "lot_no"], name: "index_auction_lots_on_auction_id_and_lot_no", unique: true
    t.index ["auction_id"], name: "index_auction_lots_on_auction_id"
    t.index ["item_id"], name: "one_open_lot_per_item", unique: true, where: "status IN ('scheduled', 'live', 'closed')"
    t.index ["leader_bid_id"], name: "index_auction_lots_on_leader_bid_id"
    t.check_constraint "bid_increment_cents IS NULL OR bid_increment_cents > 0", name: "auction_lots_increment_positive"
    t.check_constraint "lot_no BETWEEN 1 AND 10", name: "auction_lots_max_ten"
    t.check_constraint "min_price_cents > 0", name: "auction_lots_min_price_positive"
    t.check_constraint "status IN ('scheduled', 'live', 'closed', 'sold', 'unsold', 'cancelled')", name: "auction_lots_status_valid"
  end

  create_table "auction_participants", force: :cascade do |t|
    t.integer "auction_id", null: false
    t.bigint "user_id", null: false
    t.string "source", null: false
    t.string "status", null: false
    t.bigint "invited_by_id"
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "grade_at_entry", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_id", "user_id"], name: "index_auction_participants_on_auction_id_and_user_id", unique: true
    t.index ["auction_id"], name: "index_auction_participants_on_auction_id"
    t.index ["user_id", "status"], name: "index_auction_participants_on_user_id_and_status"
    t.check_constraint "(source = 'registered' AND status IN ('registered', 'revoked')) OR (source = 'invited' AND status IN ('invited', 'accepted', 'revoked'))", name: "participants_status_matches_source"
    t.check_constraint "source <> 'invited' OR invited_by_id IS NOT NULL", name: "participants_invite_has_inviter"
    t.check_constraint "source IN ('registered', 'invited')", name: "participants_source_valid"
    t.check_constraint "status IN ('registered', 'invited', 'accepted', 'revoked')", name: "participants_status_valid"
  end

  create_table "auctions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "auction_type", null: false
    t.string "visibility", default: "public", null: false
    t.string "status", default: "draft", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "scheduled_at"
    t.datetime "cancelled_at"
    t.text "cancel_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "starts_at"], name: "index_auctions_on_status_and_starts_at"
    t.check_constraint "auction_type <> 'english' OR visibility = 'invite_only'", name: "auctions_english_invite_only"
    t.check_constraint "auction_type IN ('sealed_first_price', 'english')", name: "auctions_type_valid"
    t.check_constraint "ends_at > starts_at", name: "auctions_ends_after_starts"
    t.check_constraint "status <> 'cancelled' OR cancel_reason IS NOT NULL", name: "auctions_cancel_has_reason"
    t.check_constraint "status IN ('draft', 'scheduled', 'live', 'awaiting_approval', 'published', 'cancelled')", name: "auctions_status_valid"
    t.check_constraint "visibility IN ('public', 'invite_only')", name: "auctions_visibility_valid"
  end

  create_table "bids", force: :cascade do |t|
    t.integer "lot_id", null: false
    t.bigint "user_id", null: false
    t.string "auction_type", null: false
    t.text "amount_cents", null: false
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.index ["lot_id", "created_at"], name: "index_bids_on_lot_id_and_created_at"
    t.index ["lot_id", "user_id"], name: "one_sealed_bid_per_user", unique: true, where: "auction_type = 'sealed_first_price'"
    t.index ["user_id", "idempotency_key"], name: "index_bids_on_user_id_and_idempotency_key", unique: true
    t.check_constraint "auction_type IN ('sealed_first_price', 'english')", name: "bids_type_valid"
    t.check_constraint "length(idempotency_key) BETWEEN 1 AND 200", name: "bids_idempotency_key_length"
  end

  add_foreign_key "auction_lots", "auctions"
  add_foreign_key "auction_lots", "bids", column: "leader_bid_id"
  add_foreign_key "auction_participants", "auctions"
  add_foreign_key "bids", "auction_lots", column: "lot_id"
end
