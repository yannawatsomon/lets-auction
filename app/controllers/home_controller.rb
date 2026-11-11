class HomeController < ApplicationController
  include CatalogPage

  def index
    prepare_catalog(url: root_path)
  end
end
