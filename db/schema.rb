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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_080100) do
  create_table "auction_lots", force: :cascade do |t|
    t.integer "auction_id", null: false
    t.bigint "item_id", null: false
    t.integer "lot_no", null: false
    t.bigint "min_price_cents", null: false
    t.bigint "bid_increment_cents"
    t.bigint "current_price_cents"
    t.bigint "leader_bid_id"
    t.datetime "ends_at", null: false
    t.datetime "original_ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.integer "bid_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_id", "item_id"], name: "index_auction_lots_on_auction_id_and_item_id", unique: true
    t.index ["auction_id", "lot_no"], name: "index_auction_lots_on_auction_id_and_lot_no", unique: true
    t.index ["auction_id"], name: "index_auction_lots_on_auction_id"
    t.index ["item_id"], name: "one_open_lot_per_item", unique: true, where: "status IN ('scheduled', 'live', 'closed')"
    t.check_constraint "bid_increment_cents IS NULL OR bid_increment_cents > 0", name: "auction_lots_increment_positive"
    t.check_constraint "lot_no BETWEEN 1 AND 10", name: "auction_lots_max_ten"
    t.check_constraint "min_price_cents > 0", name: "auction_lots_min_price_positive"
    t.check_constraint "status IN ('scheduled', 'live', 'closed', 'sold', 'unsold', 'cancelled')", name: "auction_lots_status_valid"
  end

  create_table "auctions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "auction_type", null: false
    t.string "visibility", default: "public", null: false
    t.string "status", default: "draft", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "extension_window_sec", default: 120, null: false
    t.integer "extension_sec", default: 120, null: false
    t.integer "extension_cap_sec", default: 1800, null: false
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

  add_foreign_key "auction_lots", "auctions"
end
