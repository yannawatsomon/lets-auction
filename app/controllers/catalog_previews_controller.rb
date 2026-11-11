class CatalogPreviewsController < ApplicationController
  include CatalogPage

  def show
    return head :not_found unless Rails.env.development?

    prepare_catalog(url: "/catalog-preview")
  end
end
