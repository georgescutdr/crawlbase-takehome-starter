# Crawlbase Take-Home — Tudor Georgescu

## How to run

To start the full system:

```bash
docker compose up --build
```

This starts:

* Redis (rate limit storage)
* Sinatra application
* Nginx reverse proxy

### Base URL

```text
http://localhost:8080
```

### Endpoints

#### Health check

```bash
curl http://localhost:8080/health
```

#### Track request

```bash
curl -X POST http://localhost:8080/track \
  -H "X-Api-Token: test123"
```

#### Get stats

```bash
curl http://localhost:8080/stats/test123
```

#### Test rate limiting

```bash
./test_rate_limit.sh
```

---

## Design decisions

### Window strategy

I implemented a **fixed window rate limiting strategy**.

Each token is grouped into 60-second buckets using:

```ruby
window = Time.now.to_i / WINDOW_SECONDS
key = "rate:#{token}:#{window}"
```

This means all requests within the same minute share a single Redis counter.

I chose this approach because it is simple, efficient, and satisfies the requirements while keeping Redis operations O(1).

### Atomicity in Redis

Rate limiting is enforced using:

* `INCR` to atomically increment the request counter
* `EXPIRE` to automatically remove counters after the window ends

Redis guarantees that `INCR` is atomic, ensuring correctness even when multiple requests arrive concurrently.

### Nginx reverse proxy

Nginx acts as the public entrypoint:

* Exposes port `8080`
* Proxies requests to the Sinatra application on `app:4567`
* Forwards client IP information using:

  * `X-Real-IP`
  * `X-Forwarded-For`
* Adds a custom response header:

```text
X-Proxy: crawlbase-nginx
```

---

## Tradeoffs / what I'd do with more time

I intentionally chose a fixed-window implementation because it is straightforward and performs well for this exercise.

A limitation of fixed-window rate limiting is that it allows bursts at window boundaries. For example:

```text
59 requests at 12:00:59
+
59 requests at 12:01:00
```

This can result in more requests being accepted in a short period than intended.

With more time, I would implement a **sliding window** approach using Redis sorted sets:

* Tracks individual request timestamps
* Provides more accurate rate limiting
* Prevents boundary burst issues
* Requires more Redis operations and storage

I would also add:

* Automated RSpec tests
* Structured logging
* Metrics and monitoring
* Additional error handling and validation

---

## AI tooling

### Tools used

I used ChatGPT to help:

* Design the Redis-based rate limiting approach
* Configure the Nginx reverse proxy
* Debug Docker Compose setup issues
* Generate test scripts
* Review and improve documentation

### One thing the agent got right

The agent correctly suggested using Redis `INCR` combined with `EXPIRE` to implement a simple fixed-window rate limiter. This saved time and matched the requirements well.

### One thing the agent got wrong

The agent initially suggested more advanced solutions such as sliding windows and token bucket algorithms. While useful in production systems, these approaches were more complex than necessary for the scope of this exercise.

I caught this by revisiting the requirements and choosing the simplest solution that satisfied them.
