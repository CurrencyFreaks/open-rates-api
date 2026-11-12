# Crawler image: fetches rates from providers and writes them to the database. Run exactly one copy.
# Build from the repository root:
#   docker build -f crawler/Dockerfile -t open-rates-crawler:local .

# --- Build stage: compile gems with the full toolchain ---
FROM ruby:4.0.9-slim AS builder

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock mise.toml ./

RUN gem install bundler && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# --- Runtime stage: only what the app needs to run ---
FROM ruby:4.0.9-slim

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 frankfurter

RUN mkdir /app && chown frankfurter:frankfurter /app
WORKDIR /app

# Copy the compiled bundle (gems + bundler config) from the builder
COPY --from=builder --chown=frankfurter:frankfurter /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=frankfurter:frankfurter /app/vendor /app/vendor

# Only the shared code and the crawler itself; the API is not part of this image.
COPY --chown=frankfurter:frankfurter Gemfile Gemfile.lock mise.toml ./
COPY --chown=frankfurter:frankfurter shared ./shared
COPY --chown=frankfurter:frankfurter crawler ./crawler

ENV APP_ENV=production
ENV BUNDLE_GEMFILE=/app/Gemfile
# YJIT refreshes blends about 8% faster at no measurable memory cost; ZJIT was within noise on Ruby 4.0.7.
ENV RUBY_YJIT_ENABLE=1

USER frankfurter
WORKDIR /app/crawler

# Migrate and seed (safe to repeat on every start), then run the scheduler. No HTTP port, so no HTTP healthcheck.
CMD ["sh", "-c", "bundle exec rake db:setup && exec bundle exec ruby bin/schedule"]
