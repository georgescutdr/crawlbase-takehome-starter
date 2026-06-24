require "sinatra"
require "redis"
require "json"

# --- Configuration -----------------------------------------------------------
set :bind, "0.0.0.0"
set :port, 4567

REQUEST_LIMIT  = 60   # requests allowed per token...
WINDOW_SECONDS = 60   # ...within this rolling window

# Redis connection. REDIS_URL is provided by docker-compose.
def redis
  @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
end

# Read the API token from the request header (X-Api-Token).
def api_token
  request.env["HTTP_X_API_TOKEN"]
end

before do
  content_type :json
end

# -----------------------------------------------------------------------------
# POST /track
#
# Rate limiting strategy: Fixed Window Counter
#
# We limit each API token to REQUEST_LIMIT (60) requests per WINDOW_SECONDS (60s).
#
# How it works:
# - We group requests into fixed 60-second "buckets" using:
#     window = Time.now.to_i / WINDOW_SECONDS
# - Each token + window combination maps to a unique Redis key:
#     rate:{token}:{window}
#
# Example:
#   rate:test123:28765432
#
# Redis usage:
# - INCR ensures atomic increment (safe under concurrent requests)
# - EXPIRE ensures automatic cleanup after the window ends
#
# Behavior:
# - If count <= REQUEST_LIMIT → return 200 with usage info
# - If count > REQUEST_LIMIT → return 429 + Retry-After header
#
# Tradeoff:
# - This is a FIXED WINDOW algorithm:
#   It is simple and efficient but can allow burst traffic at window boundaries.
#
# Production alternative:
# - Sliding window (Redis ZSET) for accuracy
# - Token bucket for smoother rate limiting and burst control
# -----------------------------------------------------------------------------
post "/track" do
  token = api_token
  halt 400, { error: "Missing X-Api-Token header" }.to_json if token.nil? || token.empty?

  window = Time.now.to_i / WINDOW_SECONDS
  key = "rate:#{token}:#{window}"

  count = redis.incr(key)

  # Set expiry only once (first hit)
  if count == 1
    redis.expire(key, WINDOW_SECONDS)
  end

  if count > REQUEST_LIMIT
    retry_after = redis.ttl(key)
    headers "Retry-After" => retry_after.to_s

    halt 429, {
      error: "Rate limit exceeded",
      limit: REQUEST_LIMIT,
      window_seconds: WINDOW_SECONDS
    }.to_json
  end

  {
    token: token,
    count: count,
    limit: REQUEST_LIMIT,
    remaining: REQUEST_LIMIT - count
  }.to_json
end

# --- GET /stats/:token -------------------------------------------------------
# Return the current request count and remaining quota for a token.
# TODO: return the current count and remaining quota for this token in the active window.
get "/stats/:token" do
  token = params["token"]
  window = Time.now.to_i / WINDOW_SECONDS
  key = "rate:#{token}:#{window}"

  count = redis.get(key).to_i

  {
    token: token,
    count: count,
    limit: REQUEST_LIMIT,
    remaining: [REQUEST_LIMIT - count, 0].max
  }.to_json
end

# --- GET /health (already implemented) ---------------------------------------
get "/health" do
  { status: "ok" }.to_json
end

get "/" do
  content_type :json

  {
    message: "Crawlbase Take-Home API is running",
    endpoints: [
      "/health",
      "/track (POST)",
      "/stats/:token"
    ]
  }.to_json
end
