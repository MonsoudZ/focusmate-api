require "sidekiq/web"
require "sidekiq-scheduler/web"

Rails.application.routes.draw do
  # Protect Sidekiq web UI in production
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # Compare raw credentials securely (don't hash before comparing)
      # The secure_compare method already prevents timing attacks
      ActiveSupport::SecurityUtils.secure_compare(username, ENV["SIDEKIQ_USERNAME"].to_s) &
      ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_PASSWORD"].to_s)
    end
  end

  mount Sidekiq::Web => "/sidekiq"

  # API routes (stateless JWT) - define these first to take precedence
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # ===== EXISTING (KEEP) =====

      # Devices API - Full CRUD
      resources :devices, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          post :register  # Legacy endpoint for iOS compatibility
          post :test_push # Test push notifications
        end
      end

      # Device token management for iOS push notifications (legacy)
      patch "users/device_token", to: "users#update_device_token"  # iOS also uses this

      # Authentication routes
      post "login", to: "authentication#login"
      post "register", to: "authentication#register"
      delete "logout", to: "authentication#logout"
      get "profile", to: "authentication#profile"

      # iOS app compatibility routes
      post "auth/sign_in", to: "authentication#login"
      post "auth/sign_up", to: "authentication#register"
      delete "auth/sign_out", to: "authentication#logout"

      # Test routes (available in test and development)
      if Rails.env.development? || Rails.env.test?
        get "test-profile", to: "authentication#test_profile"
        get "test-lists", to: "authentication#test_lists"
        delete "test-logout", to: "authentication#test_logout"
      end


      # ===== ENHANCED LIST ROUTES =====
      resources :lists do
        collection do
          get :validate_access, path: "validate/:id"  # Check if user can access a specific list
        end
        # EXISTING
        resources :memberships, except: [ :new, :edit ]
        resources :tasks, except: [ :new, :edit ] do
          member do
            # EXISTING
            patch :reassign              # Also support PATCH for iOS compatibility

            # NEW - Accountability features
            post :complete              # Complete task (POST for compatibility)
            patch :complete             # Complete task (PATCH for REST)
            patch :uncomplete           # Undo completion
            post :submit_explanation    # Submit reason for missing task
            patch :toggle_visibility    # Hide/show from specific coach
            patch :change_visibility    # Change task visibility (public/private/coaching_only)
          end
        end


        # NEW - List sharing with coaches
        resources :shares, only: [ :index, :show, :create, :update, :destroy ], controller: "list_shares" do
          member do
            patch :update_permissions  # Update what coach can do
            post :accept               # Accept invitation
            post :decline              # Decline invitation
          end
        end


        # iOS compatibility - singular share route
        post "share", to: "list_shares#create"

        # Member routes - these use :id and won't conflict with nested :list_id routes
        member do
          patch :unshare
          post :share
          get :members
          get :tasks
        end
      end

      # List share invitation acceptance (public endpoint, no auth required)
      post "list_shares/accept", to: "list_shares#accept_invitation"



      # iOS app compatibility - global /tasks routes
      get "tasks", to: "tasks#all_tasks"
      post "tasks", to: "tasks#create"

      # ===== NEW - TASK SPECIAL ENDPOINTS =====
      # Task actions (no-snooze flow)
      resources :tasks, only: [ :show, :update, :destroy ] do
        collection do
          get :all_tasks            # Get all tasks across all lists
          get :blocking              # Get tasks blocking the app
          get :awaiting_explanation  # Tasks needing explanation
          get :overdue              # All overdue tasks
        end

        member do
          # Task completion actions
          post :complete              # Complete task (POST for compatibility)
          patch :complete             # Complete task (PATCH for REST)
          patch :uncomplete
          patch :reassign
          post :submit_explanation
          patch :toggle_visibility
          patch :change_visibility

          # Subtask management
          post   :add_subtask
          patch  :update_subtask
          delete :delete_subtask
        end
      end

      # ===== NEW - COACHING RELATIONSHIPS =====
      resources :coaching_relationships, only: [ :index, :create, :show, :destroy ] do
        member do
          patch :accept              # Accept invitation
          patch :decline             # Decline invitation
          patch :update_preferences  # Update notification preferences
        end

        resources :daily_summaries, only: [ :index, :show ]
      end

      # ===== NEW - LOCATION FEATURES =====
      resources :saved_locations, only: [ :index, :show, :create, :update, :destroy ]

      # User location updates
      post "users/location", to: "users#update_location"
      patch "users/fcm_token", to: "users#update_fcm_token"
      patch "users/preferences", to: "users#update_preferences"

      # ===== NEW - RECURRING TASKS =====
      resources :recurring_templates, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :generate_instance    # Manually generate next instance
          get :instances             # See all instances
        end
      end

      # ===== NEW - NOTIFICATIONS & ESCALATIONS =====
      resources :notifications, only: [ :index ] do
        collection do
          patch :mark_all_read
        end
        member do
          patch :mark_read
        end
      end

      # ===== DASHBOARD / STATS =====
      get "dashboard", to: "dashboard#show"
      get "dashboard/stats", to: "dashboard#stats"
    end
  end

  # ActionCable
  mount ActionCable.server => "/cable"

  # Devise (web) - keep away from /api, skip session routes
  devise_for :users, skip: [ :sessions, :registrations, :passwords ]

  # Health check endpoints
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :health do
    get :live
    get :ready
    get :detailed
    get :metrics
  end
end
