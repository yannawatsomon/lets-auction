# Temporary, read-only public demo requested for the Railway catalog.
# Set CATALOG_DEMO=false to hide synthetic inventory in production.
Rails.application.config.x.catalog_demo_in_production = ENV.fetch("CATALOG_DEMO", "true") == "true"
