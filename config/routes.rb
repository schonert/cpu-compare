Rails.application.routes.draw do
  root "comparisons#show"

  get "compare", to: "comparisons#show", as: :compare
  get "processors", to: "cpus#index", as: :cpus
  get "processors/search", to: "cpus#search", as: :search_cpus

  # Every figure on the site links to its own measurements.
  get "measurements/:id", to: "measurements#show", as: :measurements

  get "methodology", to: "methodology#show", as: :methodology

  get "up" => "rails/health#show", as: :rails_health_check
end
