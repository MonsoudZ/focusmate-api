# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq-scheduler/web"

Rails.application.routes.draw do
  # ----------------------------
  # Devise (JWT auth)
  # ----------------------------
  devise_for :users,
             path: "api/v1/auth",
             path_names: { sign_in: "sign_in", sign_out: "sign_out", registration: "sign_up" },
             controllers: { sessions: "api/v1/sessions", registrations: "api/v1/registrations" },
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
  # API v1 (iOS frontend)
  # ----------------------------
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # ---- Devices (APNs push) ----
      resources :devices, only: %i[create destroy] do
        collection { post :test_push }
      end

      # ---- Cross-list tasks (Inbox / Today / Overdue) ----
      resources :tasks, only: %i[index]

      # ---- Lists ----
      resources :lists do
        # Sharing & permissions
        resources :memberships, only: %i[index create update destroy]

        # Canonical task CRUD (scoped to list)
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

      # ---- Coaching (relationship only) ----
      resources :coaching_relationships, only: %i[index show create update destroy]

      # ---- Notifications ----
      resources :notifications, only: %i[index] do
        collection { patch :mark_all_read }
        member { patch :mark_read }
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
