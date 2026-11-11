module CatalogPage
  extend ActiveSupport::Concern

  private

  def prepare_catalog(url:)
    @now = Time.current
    @catalog_url = url
    @demo_catalog = Catalog::DemoLots.enabled?
    page_attributes = Catalog::Pagination::FIELDS.to_h { |field| [ field, params[field] ] }
    @pagination = Catalog::Pagination.new(page_attributes)
    @pagination.valid?
    attributes = Catalog::Filters::FIELDS.to_h { |field| [ field, params[field] ] }
    @filters = Catalog::Filters.new(attributes, categories: [])
    lots = Catalog::DemoLots.call(now: @now)
    @categories = lots.map(&:category).uniq.sort
    @filters = Catalog::Filters.new(attributes, categories: @categories)
    @sections = @filters.sections(lots: lots, now: @now)
    if @filters.errors.any? || @pagination.errors.any?
      @sections = @sections.transform_values { [] }
      response.status = :unprocessable_content
    end
  rescue Catalog::InventoryUnavailable
    @categories = [ @filters.category ].reject(&:empty?)
    @sections = {}
    @catalog_load_error = true
    response.status = :service_unavailable
  end
end
