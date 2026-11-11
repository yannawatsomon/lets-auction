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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_100006) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "item_media", force: :cascade do |t|
    t.integer "item_id", null: false
    t.string "kind", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "kind", "sort_order"], name: "index_item_media_on_item_id_and_kind_and_sort_order"
    t.index ["item_id"], name: "index_item_media_on_item_id"
    t.check_constraint "kind IN ('image', 'video', 'document')", name: "item_media_kind_valid"
  end

  create_table "item_reviews", force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "admin_id", null: false
    t.string "action", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.index ["admin_id"], name: "index_item_reviews_on_admin_id"
    t.index ["item_id"], name: "index_item_reviews_on_item_id"
    t.check_constraint "action IN ('approve', 'reject', 'request_info')", name: "item_reviews_action_valid"
  end

  create_table "items", force: :cascade do |t|
    t.integer "seller_id", null: false
    t.integer "category_id", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.bigint "min_price_cents", null: false
    t.string "status", default: "pending_review", null: false
    t.string "contact_channel"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_items_on_category_id"
    t.index ["seller_id", "status"], name: "index_items_on_seller_id_and_status"
    t.index ["seller_id"], name: "index_items_on_seller_id"
    t.index ["status", "category_id"], name: "index_items_on_status_and_category_id"
    t.check_constraint "min_price_cents > 0", name: "items_min_price_positive"
    t.check_constraint "status IN ('pending_review', 'info_requested', 'approved', 'rejected', 'in_auction', 'sold', 'withdrawn')", name: "items_status_valid"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "role", default: "buyer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "role IN ('buyer', 'seller', 'admin')", name: "users_role_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "item_media", "items"
  add_foreign_key "item_reviews", "items"
  add_foreign_key "item_reviews", "users", column: "admin_id"
  add_foreign_key "items", "categories"
  add_foreign_key "items", "users", column: "seller_id"
end
