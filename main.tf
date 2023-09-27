terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_iam_policy_document" "role" {
  // Create an IAM role via Terraform
  statement {
    // Effect can either allow or prevent a resource from using certain allowed services
    effect = "Allow"

    // Defines the services the role will have access to
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    // AssumeRole allows giving temporary security clearance without creating a permanent policy
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "part_one_role" {
  assume_role_policy = data.aws_iam_policy_document.role.json
}

resource "aws_lambda_function" "HelloWorld" {
  function_name = "HelloWorldFunction"
  role = aws_iam_role.part_one_role.arn
  filename = "target/HelloLambdaWorld-1.0-SNAPSHOT.jar"
  runtime = "java17"
  handler = "example.HelloWorldHandler"
  source_code_hash = filebase64sha256("target/HelloLambdaWorld-1.0-SNAPSHOT.jar")
}

resource "aws_api_gateway_rest_api" "HelloWorldAPI" {
  name = "AssignmentAPIGateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "HelloWorldResource" {
  parent_id = aws_api_gateway_rest_api.HelloWorldAPI.root_resource_id
  path_part = "HelloWorld"
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
}

resource "aws_api_gateway_method" "HelloWorldMethod" {
  authorization = "NONE"
  http_method = "ANY"
  resource_id = aws_api_gateway_resource.HelloWorldResource.id
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
}

// integration request
resource "aws_api_gateway_integration" "HelloWorldIntegrationRequest" {
  http_method = aws_api_gateway_method.HelloWorldMethod.http_method
  resource_id = aws_api_gateway_resource.HelloWorldResource.id
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
  type = "AWS"
  integration_http_method = "POST"
  content_handling = "CONVERT_TO_TEXT"
  uri = aws_lambda_function.HelloWorld.invoke_arn
}

resource "aws_api_gateway_method_response" "method_response_200" {
  http_method = aws_api_gateway_method.HelloWorldMethod.http_method
  resource_id = aws_api_gateway_resource.HelloWorldResource.id
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "time_sleep" "wait_30_seconds" {
  create_duration = "30s"
}

// integration response
resource "aws_api_gateway_integration_response" "HelloWorldIntegrationResponse" {
  depends_on = [time_sleep.wait_30_seconds]
  http_method = aws_api_gateway_method_response.method_response_200.http_method
  resource_id = aws_api_gateway_resource.HelloWorldResource.id
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
  status_code = aws_api_gateway_method_response.method_response_200.status_code
}

resource "aws_api_gateway_deployment" "HelloWorldDeployment" {
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPI.id
  stage_name = "test"
  depends_on = [aws_api_gateway_integration.HelloWorldIntegrationRequest, aws_api_gateway_integration_response.HelloWorldIntegrationResponse, aws_api_gateway_method_response.method_response_200]
}

resource "aws_lambda_permission" "HelloWorldPermission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.HelloWorld.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.HelloWorldAPI.execution_arn}/*"
}