module CatalogPage
  extend ActiveSupport::Concern

  private

  def prepare_catalog(url:)
    @now = Time.current
    @catalog_url = url
    @demo_catalog = Rails.env.local?
    lots = Catalog::DemoLots.call(now: @now)
    @categories = lots.map(&:category).uniq.sort
    attributes = Catalog::Filters::FIELDS.to_h { |field| [ field, params[field] ] }
    @filters = Catalog::Filters.new(attributes, categories: @categories)
    @sections = @filters.sections(lots: lots, now: @now)
    response.status = :unprocessable_content if @filters.errors.any?
  end
end
