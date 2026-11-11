# Pin npm packages by running ./bin/importmap

pin "application"
pin "catalog_refresh_loop", to: "lib/catalog_refresh_loop.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js" # ships with Rails; live bidding (#34)
pin_all_from "app/javascript/controllers", under: "controllers"
