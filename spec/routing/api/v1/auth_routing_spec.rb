require "rails_helper"

RSpec.describe "Auth routing", type: :routing do
  it "routes DELETE /api/v1/auth/sign_out to authentication#logout" do
    expect(delete: "/api/v1/auth/sign_out")
      .to route_to(controller: "api/v1/authentication", action: "logout", format: :json)
  end

  it "routes DELETE /api/v1/logout to authentication#logout" do
    expect(delete: "/api/v1/logout")
      .to route_to(controller: "api/v1/authentication", action: "logout", format: :json)
  end

  it "routes POST /api/v1/auth/sign_in to authentication#login" do
    expect(post: "/api/v1/auth/sign_in")
      .to route_to(controller: "api/v1/authentication", action: "login", format: :json)
  end

  it "routes POST /api/v1/login to authentication#login" do
    expect(post: "/api/v1/login")
      .to route_to(controller: "api/v1/authentication", action: "login", format: :json)
  end

  it "routes POST /api/v1/auth/sign_up to authentication#register" do
    expect(post: "/api/v1/auth/sign_up")
      .to route_to(controller: "api/v1/authentication", action: "register", format: :json)
  end

  it "routes POST /api/v1/register to authentication#register" do
    expect(post: "/api/v1/register")
      .to route_to(controller: "api/v1/authentication", action: "register", format: :json)
  end
end
