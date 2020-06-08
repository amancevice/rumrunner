ARG RUBY_VERSION=latest

FROM ruby:${RUBY_VERSION} AS lock
WORKDIR /var/task
COPY . .
RUN bundle config set --local path vendor/bundle
RUN bundle config set --local silence_root_warning 1
RUN bundle config set --local without development
RUN gem install bundler -v 2.1.4
RUN bundle install

FROM ruby:${RUBY_VERSION} AS test
WORKDIR /var/task
COPY --from=lock /usr/local/bundle /usr/local/bundle
COPY --from=lock /var/task .
RUN bundle config unset --local without
RUN bundle install
# RUN bundle exec rake

FROM ruby:${RUBY_VERSION} AS gem
WORKDIR /var/task
COPY --from=test /usr/local/bundle /usr/local/bundle
COPY --from=test /var/task .
RUN bundle exec rake gem:build
