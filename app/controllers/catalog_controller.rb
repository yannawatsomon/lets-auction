class CatalogController < ApplicationController
  include CatalogPage

  def index
    prepare_catalog(url: catalog_path)
  end
end
