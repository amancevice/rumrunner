ARG NODEJS=latest
ARG TERRAFORM=latest

FROM public.ecr.aws/lambda/nodejs:$NODEJS AS build
RUN yum install -y zip
COPY index.js package*.json /var/task/
RUN npm install --production
RUN zip -r package.zip index.js node_modules

FROM public.ecr.aws/lambda/nodejs:$NODEJS AS test
COPY --from=build /var/task/ .
RUN npm install
RUN npm test

FROM hashicorp/terraform:$TERRAFORM AS plan
WORKDIR /var/task/
COPY --from=test /var/task/ .
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
RUN terraform plan -out terraform.zip
