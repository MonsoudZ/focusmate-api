# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::ErrorHandling, type: :controller do
  include Devise::Test::ControllerHelpers

  # Create a test controller that includes the concern
  controller(ApplicationController) do
    def record_not_found
      raise ActiveRecord::RecordNotFound
    end

    def record_invalid
      user = User.new
      user.errors.add(:email, "is invalid")
      raise ActiveRecord::RecordInvalid.new(user)
    end

    def parameter_missing
      raise ActionController::ParameterMissing.new(:required_param)
    end

    def pundit_unauthorized
      raise Pundit::NotAuthorizedError
    end

    def unexpected_error
      raise StandardError, "Something went wrong"
    end

    def task_assignment_bad_request
      raise TaskAssignmentService::BadRequest, "assigned_to is required"
    end

    def task_assignment_invalid
      raise TaskAssignmentService::InvalidAssignee, "User cannot be assigned"
    end

    def task_nudge_self
      raise TaskNudgeService::SelfNudge, "You cannot nudge yourself"
    end

    def task_completion_missing_reason
      raise TaskCompletionService::MissingReasonError, "Reason is required"
    end

    def list_update_unauthorized
      raise ListUpdateService::UnauthorizedError, "You do not have permission"
    end

    def validation_error
      raise TaskUpdateService::ValidationError.new("Validation failed", details: { title: [ "can't be blank" ] })
    end
  end

  before do
    routes.draw do
      get "record_not_found" => "anonymous#record_not_found"
      get "record_invalid" => "anonymous#record_invalid"
      get "parameter_missing" => "anonymous#parameter_missing"
      get "pundit_unauthorized" => "anonymous#pundit_unauthorized"
      get "unexpected_error" => "anonymous#unexpected_error"
      get "task_assignment_bad_request" => "anonymous#task_assignment_bad_request"
      get "task_assignment_invalid" => "anonymous#task_assignment_invalid"
      get "task_nudge_self" => "anonymous#task_nudge_self"
      get "task_completion_missing_reason" => "anonymous#task_completion_missing_reason"
      get "list_update_unauthorized" => "anonymous#list_update_unauthorized"
      get "validation_error" => "anonymous#validation_error"
    end

    # Skip authentication for these tests
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  describe "error response format" do
    it "returns consistent JSON structure with code and message" do
      get :record_not_found

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("code", "message")
      expect(json["error"]["code"]).to eq("not_found")
      expect(json["error"]["message"]).to eq("Not found")
    end
  end

  describe "ActiveRecord::RecordNotFound" do
    it "returns 404 with not_found code" do
      get :record_not_found

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("not_found")
    end
  end

  describe "ActiveRecord::RecordInvalid" do
    it "returns 422 with validation_error code and details" do
      get :record_invalid

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("validation_error")
      expect(json["error"]["details"]).to have_key("email")
    end
  end

  describe "ActionController::ParameterMissing" do
    it "returns 400 with parameter_missing code" do
      get :parameter_missing

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("parameter_missing")
    end
  end

  describe "Pundit::NotAuthorizedError" do
    it "returns 403 with not_authorized code" do
      get :pundit_unauthorized

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("not_authorized")
    end
  end

  describe "StandardError (catch-all)" do
    it "returns 500 with internal_error code" do
      get :unexpected_error

      expect(response).to have_http_status(:internal_server_error)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("internal_error")
    end

    it "logs the error" do
      expect(Rails.logger).to receive(:error).at_least(:twice)
      get :unexpected_error
    end

    it "reports to Rails error handler" do
      expect(Rails.error).to receive(:report).with(
        an_instance_of(StandardError),
        hash_including(handled: true)
      )
      get :unexpected_error
    end

    context "in development/test environment" do
      it "includes error details in message" do
        allow(Rails.env).to receive(:local?).and_return(true)
        get :unexpected_error

        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to include("StandardError")
        expect(json["error"]["message"]).to include("Something went wrong")
      end
    end

    context "in production environment" do
      it "returns generic message" do
        allow(Rails.env).to receive(:local?).and_return(false)
        get :unexpected_error

        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("An unexpected error occurred")
      end
    end
  end

  describe "TaskAssignmentService errors" do
    it "handles BadRequest" do
      get :task_assignment_bad_request

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("bad_request")
    end

    it "handles InvalidAssignee" do
      get :task_assignment_invalid

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("invalid_assignee")
    end
  end

  describe "TaskNudgeService::SelfNudge" do
    it "returns 422 with self_nudge code" do
      get :task_nudge_self

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("self_nudge")
    end
  end

  describe "TaskCompletionService::MissingReasonError" do
    it "returns 422 with missing_reason code" do
      get :task_completion_missing_reason

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("missing_reason")
    end
  end

  describe "ListUpdateService::UnauthorizedError" do
    it "returns 403 with list_update_forbidden code" do
      get :list_update_unauthorized

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("list_update_forbidden")
    end
  end

  describe "validation errors with details" do
    it "returns 422 with details hash" do
      get :validation_error

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("validation_error")
      expect(json["error"]["message"]).to eq("Validation failed")
      expect(json["error"]["details"]).to eq({ "title" => [ "can't be blank" ] })
    end
  end
end
