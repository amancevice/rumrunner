ARG RUBY_VERSION=latest

FROM ruby:${RUBY_VERSION} AS install
WORKDIR /var/task/
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN gem install bundler -v 2.0.2
RUN bundle install --path vendor/bundle/

FROM ruby:${RUBY_VERSION} AS test
WORKDIR /var/task/
COPY --from=install /usr/local/bundle/ /usr/local/bundle/
COPY --from=install /var/task/ .
RUN bundle exec rake

FROM ruby:${RUBY_VERSION} AS build
WORKDIR /var/task/
COPY --from=install /usr/local/bundle/ /usr/local/bundle/
COPY --from=install /var/task/ .
RUN bundle exec rake gem:build
