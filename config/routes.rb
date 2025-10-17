require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Protect Sidekiq web UI in production
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])
      ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"])
      )
    end
  end
  
  mount Sidekiq::Web => '/sidekiq'

  devise_for :users

  # API routes
  namespace :api do
    namespace :v1 do
      # ===== EXISTING (KEEP) =====

      # Devices API
      post "devices/register", to: "devices#register"
      delete "devices/:id",    to: "devices#destroy"
      
      # Device token management for iOS push notifications
      post 'devices', to: 'devices#register'              # iOS calls this
      put 'devices/token', to: 'users#update_device_token' # iOS calls this
      patch 'users/device_token', to: 'users#update_device_token'  # iOS also uses this

      # Authentication routes
      post 'login', to: 'authentication#login'
      post 'register', to: 'authentication#register'
      get 'profile', to: 'authentication#profile'
      delete 'logout', to: 'authentication#logout'

      # iOS app expected auth routes
      post 'auth/sign_in', to: 'authentication#login'
      post 'auth/sign_up', to: 'authentication#register'
      delete 'auth/sign_out', to: 'authentication#logout'

      # Test routes (no auth required)
      get 'test-profile', to: 'authentication#test_profile'
      get 'test-lists', to: 'authentication#test_lists'
      delete 'test-logout', to: 'authentication#test_logout'

      # Example resource routes
      resources :examples

      # ===== ENHANCED LIST ROUTES =====
      resources :lists do
        # EXISTING
        resources :memberships, except: [:new, :edit]
        resources :tasks, except: [:new, :edit] do
          member do
            # EXISTING
            post :complete
            post :reassign

            # NEW - Accountability features
            patch :uncomplete           # Undo completion
            post :submit_explanation    # Submit reason for missing task
            patch :toggle_visibility    # Hide/show from specific coach
          end
        end

        # iOS app compatibility - redirect /items to /tasks
        get 'items', to: 'tasks#index'
        post 'items', to: 'tasks#create'
        get 'items/:id', to: 'tasks#show'
        patch 'items/:id', to: 'tasks#update'
        delete 'items/:id', to: 'tasks#destroy'

        # NEW - List sharing with coaches
        resources :shares, only: [:index, :create, :destroy], controller: 'list_shares' do
          member do
            patch :update_permissions  # Update what coach can do
          end
        end
      end

      # iOS app compatibility - global /items routes
      get 'items', to: 'tasks#index'
      post 'items', to: 'tasks#create'
      get 'items/:id', to: 'tasks#show'
      patch 'items/:id', to: 'tasks#update'
      delete 'items/:id', to: 'tasks#destroy'

      # ===== NEW - TASK SPECIAL ENDPOINTS =====
      # Task actions (no-snooze flow)
      resources :tasks, only: [] do
        collection do
          get :blocking              # Get tasks blocking the app
          get :awaiting_explanation  # Tasks needing explanation
          get :overdue              # All overdue tasks
        end

        member do
          # EXISTING
          post :complete
          post :reassign

          # NEW - Subtask management
          post :add_subtask
          patch 'subtasks/:subtask_id', action: :update_subtask
          delete 'subtasks/:subtask_id', action: :delete_subtask
        end
      end

      # ===== NEW - COACHING RELATIONSHIPS =====
      resources :coaching_relationships, only: [:index, :create, :show, :destroy] do
        member do
          patch :accept              # Accept invitation
          patch :decline             # Decline invitation
          patch :update_preferences  # Update notification preferences
        end

        resources :daily_summaries, only: [:index, :show]
      end

      # ===== NEW - LOCATION FEATURES =====
      resources :saved_locations, only: [:index, :create, :update, :destroy]

      # User location updates
      post 'users/location', to: 'users#update_location'
      patch 'users/fcm_token', to: 'users#update_fcm_token'
      patch 'users/preferences', to: 'users#update_preferences'

      # ===== NEW - RECURRING TASKS =====
      resources :recurring_templates, only: [:index, :create, :update, :destroy] do
        member do
          post :generate_instance    # Manually generate next instance
          get :instances             # See all instances
        end
      end

      # ===== NEW - NOTIFICATIONS & ESCALATIONS =====
      resources :notifications, only: [:index] do
        collection do
          patch :mark_all_read
        end
        member do
          patch :mark_read
        end
      end

      # ===== DASHBOARD / STATS =====
      get 'dashboard', to: 'dashboard#show'
      get 'dashboard/stats', to: 'dashboard#stats'
    end
  end

  # ActionCable
  mount ActionCable.server => "/cable"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end