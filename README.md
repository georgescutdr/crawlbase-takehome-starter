# Crawlbase Take-Home — [Tudor Georgescu]

## How to run

<!-- The command(s) to bring everything up (e.g. `docker compose up`),
     and how to hit the endpoints once it's running. 

     To start the full system:
     docker compose up --build
     
     Endpoints:
     
     Base URL
     http://localhost:8080

     Health check
     curl http://localhost:8080/health

     Track request
     curl -X POST http://localhost:8080/track -H "X-Api-Token: test123"

     Get stats
     curl http://localhost:8080/stats/test123

     Test rate limit
     ./test_rate_limit.sh
-->

## Design decisions

<!-- Explain your key choices:
     - Which window strategy did you use (fixed vs sliding) and why?
     - How did you enforce the limit atomically in Redis?
     - Anything notable about your nginx setup? 

     Window strategy:
     I implemented a fixed window rate limiting strategy. Each token is grouped into 60-second buckets using:

     window = Time.now.to_i / WINDOW_SECONDS
     key = "rate:#{token}:#{window}"

     This means all requests in the same minute share a single Redis counter.

     Atomicity in Redis:
     -Rate limiting is enforced using:
     -INCR → atomically increments request counter
     -EXPIRE → ensures automatic cleanup after the window ends
     -Redis guarantees INCR is atomic, which ensures correctness even under concurrent requests.

     Nginx reverse proxy:
     -Nginx acts as the public entrypoint
     -Exposes port 8080 to the host
     -Forwards traffic to app:4567
     -Adds a custom header for observability:
     -X-Proxy: crawlbase-nginx

-->

## Tradeoffs / what I'd do with more time

<!-- What did you intentionally skip or simplify, and what would you
     revisit before this went to production? 
     I simplified the algorythm, making it with fixed-window rate limiting, 
     allowing it to have 59 requests at 12:00:59 + 59 requests at 12:01:00 = burst above limit in a very short time window
     
     I would implement sliding window:
      -tracks timestamps of requests
      -more accurate rate limiting
      -prevents boundary burst issues
      -higher Redis cost
-->

## AI tooling

<!-- Please be specific and honest:
     - Which AI tools you used, and for what.
       I used ChatGPT for all files

     - One thing the agent got right that saved you time.
       Correctly suggested using Redis INCR + EXPIRE for fixed-window rate limiting

     - One thing it got wrong or led you astray on, and how you caught it. 
       Initially overcomplicated the solution by suggesting sliding window / token bucket implementations for the core requirement


-->
