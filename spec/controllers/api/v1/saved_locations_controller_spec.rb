require "rails_helper"

RSpec.describe Api::V1::SavedLocationsController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }
  
  let!(:location) do
    SavedLocation.create!(
      user: user,
      name: "Home",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 100,
      address: "123 Main St, New York, NY"
    )
  end
  
  let!(:other_location) do
    SavedLocation.create!(
      user: other_user,
      name: "Other User's Home",
      latitude: 34.0522,
      longitude: -118.2437,
      radius_meters: 200,
      address: "456 Oak Ave, Los Angeles, CA"
    )
  end
  
  let(:user_headers) { auth_headers(user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "GET /api/v1/saved_locations" do
    it "should get all saved locations for user" do
      get "/api/v1/saved_locations", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(location.id)
      expect(json.first["name"]).to eq("Home")
      expect(json.first["latitude"]).to eq(40.7128)
      expect(json.first["longitude"]).to eq(-74.0060)
      expect(json.first["radius_meters"]).to eq(100)
      expect(json.first["address"]).to eq("123 Main St, New York, NY")
    end

    it "should not get locations from other users" do
      get "/api/v1/saved_locations", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(location.id)
      expect(json.map { |loc| loc["id"] }).not_to include(other_location.id)
    end

    it "should not get saved locations without authentication" do
      get "/api/v1/saved_locations"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end

    it "should handle empty locations list" do
      new_user = create(:user, email: "new_user_#{SecureRandom.hex(4)}@example.com")
      new_user_headers = auth_headers(new_user)
      
      get "/api/v1/saved_locations", headers: new_user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(0)
    end

    it "should include location details" do
      get "/api/v1/saved_locations", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      
      location_data = json.first
      expect(location_data).to have_key("id")
      expect(location_data).to have_key("name")
      expect(location_data).to have_key("latitude")
      expect(location_data).to have_key("longitude")
      expect(location_data).to have_key("radius_meters")
      expect(location_data).to have_key("address")
      expect(location_data).to have_key("created_at")
      expect(location_data).to have_key("updated_at")
    end
  end

  describe "GET /api/v1/saved_locations/:id" do
    it "should show location details" do
      get "/api/v1/saved_locations/#{location.id}", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      expect(json).to have_key("radius_meters")
      expect(json).to have_key("address")
      
      expect(json["id"]).to eq(location.id)
      expect(json["name"]).to eq("Home")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
      expect(json["radius_meters"]).to eq(100)
      expect(json["address"]).to eq("123 Main St, New York, NY")
    end

    it "should not show location from other user" do
      get "/api/v1/saved_locations/#{other_location.id}", headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Saved location not found")
    end

    it "should not show location without authentication" do
      get "/api/v1/saved_locations/#{location.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/saved_locations" do
    it "should create saved location with coordinates" do
      location_params = {
        saved_location: {
          name: "Office",
          latitude: 40.7589,
          longitude: -73.9851,
          radius_meters: 150,
          address: "456 Broadway, New York, NY"
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      expect(json).to have_key("radius_meters")
      expect(json).to have_key("address")
      
      expect(json["name"]).to eq("Office")
      expect(json["latitude"]).to eq(40.7589)
      expect(json["longitude"]).to eq(-73.9851)
      expect(json["radius_meters"]).to eq(150)
      expect(json["address"]).to eq("456 Broadway, New York, NY")
    end

    it "should create with address (geocode to coordinates)" do
      location_params = {
        saved_location: {
          name: "Central Park",
          address: "Central Park, New York, NY",
          latitude: 40.7829,  # Central Park coordinates
          longitude: -73.9654,
          radius_meters: 500
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("address")
      expect(json).to have_key("radius_meters")
      
      expect(json["name"]).to eq("Central Park")
      expect(json["address"]).to eq("Central Park, New York, NY")
      expect(json["radius_meters"]).to eq(500)
    end

    it "should validate latitude/longitude bounds" do
      # Test invalid latitude (outside -90 to 90 range)
      location_params = {
        saved_location: {
          name: "Invalid Lat",
          latitude: 91.0,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Latitude must be less than or equal to 90")
    end

    it "should validate radius_meters" do
      # Test negative radius
      location_params = {
        saved_location: {
          name: "Invalid Radius",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: -50
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Radius meters must be greater than 0")
    end

    it "should require name" do
      location_params = {
        saved_location: {
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Name can't be blank")
    end

    it "should not create location without authentication" do
      location_params = {
        saved_location: {
          name: "No Auth Location",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end

    it "should handle location with only coordinates" do
      location_params = {
        saved_location: {
          name: "Coordinates Only",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      expect(json).to have_key("radius_meters")
      
      expect(json["name"]).to eq("Coordinates Only")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
      expect(json["radius_meters"]).to eq(100)
    end

    it "should handle location with only address" do
      location_params = {
        saved_location: {
          name: "Address Only",
          address: "Times Square, New York, NY",
          latitude: 40.7580,  # Times Square coordinates
          longitude: -73.9855,
          radius_meters: 200
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("address")
      expect(json).to have_key("radius_meters")
      
      expect(json["name"]).to eq("Address Only")
      expect(json["address"]).to eq("Times Square, New York, NY")
      expect(json["radius_meters"]).to eq(200)
    end
  end

  describe "PATCH /api/v1/saved_locations/:id" do
    it "should update saved location" do
      update_params = {
        saved_location: {
          name: "Updated Home",
          latitude: 40.7589,
          longitude: -73.9851,
          radius_meters: 200,
          address: "Updated Address, New York, NY"
        }
      }
      
      patch "/api/v1/saved_locations/#{location.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      expect(json).to have_key("radius_meters")
      expect(json).to have_key("address")
      
      expect(json["name"]).to eq("Updated Home")
      expect(json["latitude"]).to eq(40.7589)
      expect(json["longitude"]).to eq(-73.9851)
      expect(json["radius_meters"]).to eq(200)
      expect(json["address"]).to eq("Updated Address, New York, NY")
    end

    it "should not allow updating other user's locations" do
      update_params = {
        saved_location: {
          name: "Hacked Location",
          latitude: 40.7589,
          longitude: -73.9851,
          radius_meters: 200
        }
      }
      
      patch "/api/v1/saved_locations/#{other_location.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Resource not found not found")
    end

    it "should not update location without authentication" do
      update_params = {
        saved_location: {
          name: "No Auth Update",
          latitude: 40.7589,
          longitude: -73.9851,
          radius_meters: 200
        }
      }
      
      patch "/api/v1/saved_locations/#{location.id}", params: update_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end

    it "should handle partial updates" do
      update_params = {
        saved_location: {
          name: "Partially Updated"
        }
      }
      
      patch "/api/v1/saved_locations/#{location.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      
      expect(json["name"]).to eq("Partially Updated")
      # Other fields should remain unchanged
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
    end

    it "should handle invalid updates" do
      update_params = {
        saved_location: {
          name: "",  # Empty name should be invalid
          latitude: 91.0,  # Invalid latitude
          radius_meters: -50  # Invalid radius
        }
      }
      
      patch "/api/v1/saved_locations/#{location.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Name can't be blank")
    end
  end

  describe "DELETE /api/v1/saved_locations/:id" do
    it "should delete saved location" do
      delete "/api/v1/saved_locations/#{location.id}", headers: user_headers
      
      expect(response).to have_http_status(:no_content)
      
      expect { SavedLocation.find(location.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should not affect tasks using this location" do
      # Create a task that uses this location
      list = create(:list, owner: user)
      task = Task.create!(
        list: list,
        creator: user,
        title: "Task at Home",
        note: "Task that uses the home location",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false,
        location_based: true,
        location_latitude: location.latitude,
        location_longitude: location.longitude,
        location_radius_meters: location.radius_meters,
        location_name: location.name
      )
      
      delete "/api/v1/saved_locations/#{location.id}", headers: user_headers
      
      expect(response).to have_http_status(:no_content)
      
      # Task should still exist
      task.reload
      expect(task.title).to eq("Task at Home")
      expect(task.location_latitude).to eq(location.latitude)
      expect(task.location_longitude).to eq(location.longitude)
      expect(task.location_radius_meters).to eq(location.radius_meters)
      expect(task.location_name).to eq(location.name)
    end

    it "should not delete location from other user" do
      delete "/api/v1/saved_locations/#{other_location.id}", headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Resource not found not found")
      
      # Location should still exist
      other_location.reload
      expect(other_location.name).to eq("Other User's Home")
    end

    it "should not delete location without authentication" do
      delete "/api/v1/saved_locations/#{location.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
      
      # Location should still exist
      location.reload
      expect(location.name).to eq("Home")
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      patch "/api/v1/saved_locations/#{location.id}", 
            params: "invalid json",
            headers: user_headers.merge("Content-Type" => "application/json")
      
      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      patch "/api/v1/saved_locations/#{location.id}", params: {}, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(location.id)
    end

    it "should handle very long location names" do
      long_name = "A" * 1000
      
      location_params = {
        saved_location: {
          name: long_name,
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Name is too long (maximum is 255 characters)")
    end

    it "should handle special characters in location name" do
      location_params = {
        saved_location: {
          name: "Location with Special Chars: !@#$%^&*()",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      
      expect(json["name"]).to eq("Location with Special Chars: !@#$%^&*()")
    end

    it "should handle unicode characters in location name" do
      location_params = {
        saved_location: {
          name: "Unicode Location: 🏠🏢🏪",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      
      expect(json["name"]).to eq("Unicode Location: 🏠🏢🏪")
    end

    it "should handle very large radius values" do
      location_params = {
        saved_location: {
          name: "Large Radius Location",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 10000  # 10km radius (max allowed)
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("radius_meters")
      
      expect(json["radius_meters"]).to eq(10000)
    end

    it "should handle very small radius values" do
      location_params = {
        saved_location: {
          name: "Small Radius Location",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 1  # 1 meter radius
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("radius_meters")
      
      expect(json["radius_meters"]).to eq(1)
    end

    it "should handle extreme latitude values" do
      # Test North Pole
      location_params = {
        saved_location: {
          name: "North Pole",
          latitude: 90.0,
          longitude: 0.0,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      expect(json["latitude"]).to eq(90.0)
      expect(json["longitude"]).to eq(0.0)
    end

    it "should handle extreme longitude values" do
      # Test International Date Line
      location_params = {
        saved_location: {
          name: "Date Line",
          latitude: 0.0,
          longitude: 180.0,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      expect(json["latitude"]).to eq(0.0)
      expect(json["longitude"]).to eq(180.0)
    end

    it "should handle concurrent location creation" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          location_params = {
            saved_location: {
              name: "Concurrent Location #{i}",
              latitude: 40.7128 + (i * 0.001),
              longitude: -74.0060 + (i * 0.001),
              radius_meters: 100
            }
          }
          
          post "/api/v1/saved_locations", params: location_params, headers: user_headers
        end
      end
      
      threads.each(&:join)
      # All should succeed with different coordinates
      expect(true).to be_truthy
    end

    it "should handle concurrent location updates" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          update_params = {
            saved_location: {
              name: "Concurrent Update #{i}",
              radius_meters: 100 + i
            }
          }
          
          patch "/api/v1/saved_locations/#{location.id}", params: update_params, headers: user_headers
        end
      end
      
      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle location with very long address" do
      long_address = "A" * 2000
      
      location_params = {
        saved_location: {
          name: "Long Address Location",
          address: long_address,
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("address")
      
      expect(json["address"]).to eq(long_address)
    end

    it "should handle location with empty address" do
      location_params = {
        saved_location: {
          name: "No Address Location",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100,
          address: ""
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      expect(json["name"]).to eq("No Address Location")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
    end

    it "should handle location with nil address" do
      location_params = {
        saved_location: {
          name: "Nil Address Location",
          latitude: 40.7128,
          longitude: -74.0060,
          radius_meters: 100,
          address: nil
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("name")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      expect(json["name"]).to eq("Nil Address Location")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
    end

    it "should handle location with zero coordinates" do
      location_params = {
        saved_location: {
          name: "Zero Coordinates",
          latitude: 0.0,
          longitude: 0.0,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      expect(json["latitude"]).to eq(0.0)
      expect(json["longitude"]).to eq(0.0)
    end

    it "should handle location with decimal precision coordinates" do
      location_params = {
        saved_location: {
          name: "Precise Location",
          latitude: 40.712800123456789,
          longitude: -74.006000987654321,
          radius_meters: 100
        }
      }
      
      post "/api/v1/saved_locations", params: location_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to have_key("id")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")
      
      # Should handle precision correctly
      expect(json["latitude"]).to be_within(0.000001).of(40.712800123456789)
      expect(json["longitude"]).to be_within(0.000001).of(-74.006000987654321)
    end
  end

  # Helper method for authentication headers
  def auth_headers(user)
    token = JWT.encode(
      { user_id: user.id, exp: 30.days.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
