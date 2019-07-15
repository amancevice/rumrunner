ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
RUN >&2 echo "BUILD"
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development

FROM lambci/lambda:build-${RUNTIME} AS test
RUN >&2 echo "TEST"
COPY --from=build /var/task/ .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
ARG RAKE_ENV=test
RUN bundle install --with development
RUN bundle exec rake
RUN bundle exec rake gem:build

FROM hashicorp/terraform:0.12.4 AS plan
RUN >&2 echo "PLAN"
WORKDIR /var/task/
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform -version
