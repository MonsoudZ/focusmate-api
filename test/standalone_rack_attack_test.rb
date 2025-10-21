require 'minitest/autorun'
require_relative '../config/environment'

class StandaloneRackAttackTest < Minitest::Test
  def test_rack_attack_configuration_works
    # Test that Rack::Attack configuration doesn't crash
    # This is a basic test to ensure the configuration is valid
    
    # Test that the throttled_responder lambda can be called
    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/api/v1/tasks",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" => "Test Agent",
      "rack.attack.match_data" => {
        epoch_time: Time.current.to_i,
        period: 60,
        limit: 100
      }
    }
    
    # This should not crash
    responder = Rack::Attack.throttled_responder
    assert responder
    assert_equal Proc, responder.class
    
    # Test that we can call the responder without crashing
    response = responder.call(env)
    assert response
    assert_equal Array, response.class
    assert_equal 3, response.length  # [status, headers, body]
    assert_equal 429, response[0]    # status
    assert_equal Hash, response[1].class  # headers
    assert_equal Array, response[2].class  # body
  end

  def test_rack_attack_request_creation_works
    # Test that Rack::Attack::Request can be created
    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/api/v1/tasks",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" => "Test Agent"
    }
    
    req = Rack::Attack::Request.new(env)
    assert req
    assert_equal "GET", req.request_method
    assert_equal "/api/v1/tasks", req.path
    assert_equal "127.0.0.1", req.ip
  end

  def test_rack_attack_throttle_rules_work
    # Test that throttle rules can be defined without crashing
    # This is a basic test to ensure the configuration is valid
    
    # Test that we can access the throttle rules
    assert Rack::Attack.throttles
    assert Rack::Attack.blocklists
    assert Rack::Attack.safelists
  end
end
