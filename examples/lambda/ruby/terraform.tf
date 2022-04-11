terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "lambda" {
  filename         = "package.zip"
  function_name    = "rumrunner-example"
  handler          = "index.handler"
  role             = "rumrunner"
  runtime          = "nodejs10.x"
  source_code_hash = filebase64sha256("package.zip")
}
