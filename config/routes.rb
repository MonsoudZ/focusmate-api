# frozen_string_literal: true

require "sidekiq/web"
require "digest"

Rails.application.routes.draw do
  # ----------------------------
  # Devise (JWT auth)
  # ----------------------------
  devise_for :users,
             skip: [ :sessions, :registrations, :passwords ],
             path: "api/v1/auth",
             path_names: { sign_in: "sign_in", sign_out: "sign_out", registration: "sign_up" },
             controllers: { sessions: "api/v1/sessions", registrations: "api/v1/registrations", passwords: "api/v1/passwords" },
             defaults: { format: :json }

  devise_scope :user do
    post "api/v1/auth/sign_in", to: "api/v1/sessions#create"
    delete "api/v1/auth/sign_out", to: "api/v1/sessions#destroy"

    post "api/v1/auth/sign_up", to: "api/v1/registrations#create"

    post "api/v1/auth/password", to: "api/v1/passwords#create"
    put "api/v1/auth/password", to: "api/v1/passwords#update"
    patch "api/v1/auth/password", to: "api/v1/passwords#update"
  end

  # ----------------------------
  # Sidekiq Web (ops only)
  # ----------------------------
  unless Rails.env.local?
    expected_sidekiq_username = ENV["SIDEKIQ_USERNAME"].to_s
    expected_sidekiq_password = ENV["SIDEKIQ_PASSWORD"].to_s

    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      next false if expected_sidekiq_username.blank? || expected_sidekiq_password.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(username.to_s),
        Digest::SHA256.hexdigest(expected_sidekiq_username)
      ) &&
        ActiveSupport::SecurityUtils.secure_compare(
          Digest::SHA256.hexdigest(password.to_s),
          Digest::SHA256.hexdigest(expected_sidekiq_password)
        )
    end
  end
  mount Sidekiq::Web => "/sidekiq"

  # ----------------------------
  # API v1
  # ----------------------------
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :user, only: [ :show, :update, :destroy ], controller: "users", path: "users/profile" do
        patch :password, to: "users#update_password", as: :password
      end
      resources :devices, only: %i[create destroy]
      resources :friends, only: %i[index destroy]
      resources :tags
      post "auth/apple", to: "apple_auth#create"
      post "auth/refresh", to: "auth/refresh#create"
      get "today", to: "today#index"
      post "analytics/app_opened", to: "analytics#app_opened"
      get "tasks/search", to: "tasks#search"
      resources :tasks, only: %i[index show]
      # Invite acceptance (by code)
      resources :invites, only: [ :show ], param: :code do
        member do
          post :accept
        end
      end

      resources :lists do
        resources :invites, controller: "list_invites", only: %i[index show create destroy]
        resources :memberships, only: %i[index create update destroy]
        resources :tasks do
          collection do
            post :reorder
          end
          member do
            patch :complete
            patch :reopen
            patch :assign
            patch :unassign
            post :nudge
            post :reschedule
          end
          resources :subtasks, only: [ :index, :show, :create, :update, :destroy ] do
            member do
              patch :complete
              patch :reopen
            end
          end
        end
      end
    end
  end

  # ----------------------------
  # Invite Landing Page (HTML)
  # ----------------------------
  get "invite/:code", to: "invites#show", as: :invite_page

  # ----------------------------
  # Apple App Site Association (Universal Links)
  # ----------------------------
  get ".well-known/apple-app-site-association", to: "well_known#apple_app_site_association"

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
