
Rails.application.config.assets.version = "1.0"

Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
Rails.application.config.assets.paths << Rails.root.join("node_modules/intl-tel-input/dist/css")
Rails.application.config.assets.paths << Rails.root.join("node_modules/intl-tel-input/dist/js")
Rails.application.config.assets.paths << Rails.root.join("node_modules/intl-tel-input/dist/img")
Rails.application.config.assets.paths << Rails.root.join("app/assets/fonts")
Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"
Rails.application.config.assets.precompile += %w[intlTelInput-no-assets.css intlTelInputWithUtils.min.js *.ttf *.woff *.woff2 *.otf *.png *.webp]
