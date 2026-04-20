
Rails.application.config.assets.version = "1.0"

Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
Rails.application.config.assets.paths << Rails.root.join("app/assets/fonts")
Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"
Rails.application.config.assets.precompile += %w[*.ttf *.woff *.woff2 *.otf]
