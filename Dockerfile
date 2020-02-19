ARG RUBY_VERSION=latest

FROM ruby:${RUBY_VERSION} AS install
WORKDIR /var/task/
COPY . .
RUN bundle config --local path vendor/bundle/
RUN bundle config --local silence_root_warning 1
RUN gem install bundler -v 2.1.4
RUN bundle install

FROM ruby:${RUBY_VERSION} AS test
WORKDIR /var/task/
COPY --from=install /usr/local/bundle/ /usr/local/bundle/
COPY --from=install /var/task/ .
# RUN bundle exec rake

FROM ruby:${RUBY_VERSION} AS build
WORKDIR /var/task/
COPY --from=install /usr/local/bundle/ /usr/local/bundle/
COPY --from=install /var/task/ .
RUN bundle exec rake gem:build
