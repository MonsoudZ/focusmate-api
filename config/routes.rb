# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  # ----------------------------
  # Devise (JWT auth)
  # ----------------------------
  devise_for :users,
             path: "api/v1/auth",
             path_names: { sign_in: "sign_in", sign_out: "sign_out", registration: "sign_up" },
             controllers: { sessions: "api/v1/sessions", registrations: "api/v1/registrations", passwords: "api/v1/passwords" },
             defaults: { format: :json }

  # ----------------------------
  # Sidekiq Web (ops only)
  # ----------------------------
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, ENV["SIDEKIQ_USERNAME"].to_s) &&
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_PASSWORD"].to_s)
    end
  end
  mount Sidekiq::Web => "/sidekiq"

  # ----------------------------
  # API v1
  # ----------------------------
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :user, only: [ :show, :update, :destroy ], controller: "users", path: "users/me" do
        put :password, to: "users#update_password", as: :password
      end
      resources :devices, only: %i[create destroy]
      post "auth/apple", to: "apple_auth#create"
      get "today", to: "today#index"
      resources :tasks, only: %i[index]
      resources :lists do
        resources :memberships, only: %i[index create update destroy]
        resources :tasks do
          member do
            patch :complete
            patch :reopen
            patch :snooze
            patch :assign
            patch :unassign
          end
        end
      end
    end
  end

  # ----------------------------
  # Health
  # ----------------------------
  namespace :health do
    get :live
    get :ready
    get :detailed
    get :metrics
  end
end
