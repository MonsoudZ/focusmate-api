# frozen_string_literal: true

module Middleware
  class JsonParserErrorHandler
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue ActionDispatch::Http::Parameters::ParseError
      [
        400,
        { "Content-Type" => "application/json" },
        [ { error: { message: "Invalid JSON format" } }.to_json ]
      ]
    end
  end
end
