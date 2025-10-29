# frozen_string_literal: true

# Committee configuration for OpenAPI response validation
require 'committee'

RSpec.configure do |config|
  config.before(:suite) do
    # Load OpenAPI schema
    schema_path = Rails.root.join('openapi', 'openapi.yaml')
    @committee_schema = Committee::Drivers::OpenAPI3::Driver.new.parse(schema_path)
  end

  config.after(:each, type: :request) do |example|
    # Skip validation for certain test patterns
    next if example.metadata[:skip_committee_validation]
    next unless response&.status && response.status >= 200 && response.status < 300

    # Only validate JSON responses
    next unless response.content_type&.include?('application/json')

    # Get the path and method from the example
    path = example.metadata[:request_path] || request.path
    method = example.metadata[:request_method] || request.method.downcase

    # Find the corresponding OpenAPI operation
    operation = find_operation(path, method)
    next unless operation

    # Validate response against schema
    begin
      Committee::ResponseValidator.new(operation).call(
        response.status,
        response.headers,
        JSON.parse(response.body)
      )
    rescue Committee::InvalidResponse => e
      raise "Response validation failed: #{e.message}"
    end
  end

  private

  def find_operation(path, method)
    # Convert Rails path to OpenAPI path
    openapi_path = convert_rails_path_to_openapi(path)

    # Find the operation in the schema
    return nil unless @committee_schema&.paths

    @committee_schema.paths.each do |schema_path, path_item|
      if matches_path?(openapi_path, schema_path)
        return path_item.send(method.to_sym)
      end
    end

    nil
  end

  def convert_rails_path_to_openapi(path)
    # Remove /api/v1 prefix
    path = path.gsub(/^\/api\/v1/, '')

    # Convert Rails route parameters to OpenAPI format
    # e.g., /tasks/123 -> /tasks/{id}
    path = path.gsub(/\/\d+/, '/{id}')

    path
  end

  def matches_path?(request_path, schema_path)
    # Simple path matching - could be enhanced for more complex patterns
    request_path == schema_path
  end
end
