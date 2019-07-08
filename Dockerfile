ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
RUN >&2 echo "BUILD"
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development

FROM lambci/lambda:build-${RUNTIME} AS test
RUN >&2 echo "TEST"
COPY --from=hashicorp/terraform:0.12.3 /bin/terraform /bin/
COPY --from=build /var/task/ .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --with development

FROM lambci/lambda:build-${RUNTIME} AS plan
COPY --from=test /bin/terraform /bin/
COPY --from=test /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform -version
