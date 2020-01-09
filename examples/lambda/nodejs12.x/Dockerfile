ARG RUNTIME=nodejs12.x
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY lambda.js package*.json /var/task/
RUN npm install --production
RUN zip -r lambda.zip lambda.js node_modules

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=build /var/task/ .
RUN npm install
RUN npm test

FROM hashicorp/terraform:${TERRAFORM} AS plan
WORKDIR /var/task/
COPY --from=test /var/task/ .
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
RUN terraform plan -out terraform.zip
