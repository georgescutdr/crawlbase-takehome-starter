FROM ruby:3.3-slim

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "4567"]
