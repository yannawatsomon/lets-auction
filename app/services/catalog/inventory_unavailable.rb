module Catalog
  # Providers raise this only for a transient inventory loading failure.
  class InventoryUnavailable < StandardError; end
end
