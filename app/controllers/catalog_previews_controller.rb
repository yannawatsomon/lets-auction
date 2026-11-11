class CatalogPreviewsController < ApplicationController
  PreviewLot = Data.define(:id, :name, :category, :auction_type, :starts_at, :ends_at)

  def show
    return head :not_found unless Rails.env.development?

    @now = Time.current
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
    lots = samples.map do |id, name, category, auction_type, starts, ends|
      PreviewLot.new(id, name, category, auction_type, @now + starts, @now + ends)
    end
    @categories = lots.map(&:category).uniq.sort
    attributes = Catalog::Filters::FIELDS.to_h { |field| [ field, params[field] ] }
    @filters = Catalog::Filters.new(attributes, categories: @categories)
    @sections = @filters.sections(lots: lots, now: @now)
    response.status = :unprocessable_content if @filters.errors.any?
  end
end
