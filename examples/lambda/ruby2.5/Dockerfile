ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
COPY Gemfile lambda.rb /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development --without test
RUN zip -r lambda.zip lambda.rb Gemfile* vendor

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=build /var/task/ .
COPY Rakefile .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --with test
RUN bundle exec rake

FROM lambci/lambda:build-${RUNTIME} AS plan
COPY --from=hashicorp/terraform /bin/terraform /bin/
COPY --from=test /var/task/ .
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
RUN terraform plan -out terraform.zip
