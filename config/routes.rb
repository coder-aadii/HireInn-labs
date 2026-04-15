Rails.application.routes.draw do
  get "home/index"
  devise_for :users
  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end
  root "home#index"

  get "dashboard" => "dashboard#index"
  get "careers" => "careers#index"
  get "careers/:id" => "careers#show", as: :career
  post "careers/:id/apply" => "applications#create", as: :career_applications
  resources :applications, only: %i[index show]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")

  resources "jobs" do
    member do
      patch :publish
    end

    resources :resumes, controller: "job_resumes", only: [:create] do
      collection do
        post :match
      end
    end
  end
end
