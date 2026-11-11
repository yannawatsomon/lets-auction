module Catalog
  # Read-only synthetic inventory, visibly marked as a demo on the catalog page.
  class DemoLots
    Lot = Data.define(:id, :name, :category, :auction_type, :starts_at, :ends_at, :min_price_cents)
    SCHEDULE_ANCHOR = Time.utc(2026, 11, 11, 16).freeze

    def self.enabled?
      Rails.env.local? || Rails.configuration.x.catalog_demo_in_production == true
    end

    def self.call(now:)
      return [] unless enabled?

      samples = [
        [ 3, "กล้องถ่ายภาพ", "กล้อง", "english", -2.hours, 90.minutes ],
        [ 8, "นาฬิกาคลาสสิก", "นาฬิกา", "sealed_first_price", -3.days, -2.days ],
        [ 5, "โต๊ะทำงานไม้", "เฟอร์นิเจอร์", "english", 1.day, 2.days ],
        [ 1, "รถยนต์ตัวอย่าง", "ยานยนต์", "english", -1.hour, 15.minutes ],
        [ 9, "เครื่องเสียง", "อิเล็กทรอนิกส์", "english", -4.days, -3.days ],
        [ 4, "เลนส์กล้อง", "กล้อง", "sealed_first_price", 30.minutes, 3.hours ],
        [ 2, "นาฬิกาสปอร์ต", "นาฬิกา", "sealed_first_price", -2.hours, 45.minutes ],
        [ 7, "เก้าอี้สำนักงาน", "เฟอร์นิเจอร์", "english", -2.days, -1.hour ],
        [ 6, "รถจักรยานยนต์", "ยานยนต์", "english", 2.days, 3.days ]
      ]
      samples.flat_map do |id, name, category, auction_type, starts, ends|
        5.times.map do |copy|
          title = copy.zero? ? name : "#{name} · ตัวอย่าง #{copy + 1}"
          Lot.new(id + copy * 100, title, category, auction_type, SCHEDULE_ANCHOR + starts, SCHEDULE_ANCHOR + ends,
            (35_000 + id * 17_800) * 100)
        end
      end
    end
  end
end
