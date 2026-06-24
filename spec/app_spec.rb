require "rack/test"
require "rspec"
require "redis"

ENV["RACK_ENV"] = "test"

require_relative "../app"

RSpec.describe "Rate Limiter" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  let(:token) { "test-token" }

  before do
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379")).flushdb
  end

  it "allows the 60th request" do
    59.times do
      post "/track", {}, { "HTTP_X_API_TOKEN" => token }
      expect(last_response.status).to eq(200)
    end

    post "/track", {}, { "HTTP_X_API_TOKEN" => token }

    expect(last_response.status).to eq(200)
  end

  it "blocks the 61st request" do
    60.times do
      post "/track", {}, { "HTTP_X_API_TOKEN" => token }
    end

    post "/track", {}, { "HTTP_X_API_TOKEN" => token }

    expect(last_response.status).to eq(429)
  end
end