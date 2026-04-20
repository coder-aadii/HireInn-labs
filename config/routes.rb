Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end
  root "home#index"
  get "home", to: "home#index", as: :home

  resources :careers, only: [:index, :show] do
    post :apply, to: "applications#create"
  end

  authenticate :user do
    get "dashboard", to: "dashboard#index"

    resources :jobs do
      member do
        patch :publish
      end

      resources :resumes, controller: "job_resumes", only: [:create, :destroy] do
        collection do
          post :match
        end
      end
    end

    resources :candidates, only: %i[index]
    resources :applications, only: %i[index show]
    resource :profile, only: %i[new create show edit update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
