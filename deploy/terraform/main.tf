data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../src/lambda/lam.py"
  output_path = "${path.module}/../../src/lambda/lam.zip"
}

# add resource lambda function python lam to be a backend for the api gateway
resource "aws_lambda_function" "lam" {
  function_name = "${local.resourceName}-lam"
  handler = "lam.handler"
  runtime = "python3.8"
  role = aws_iam_role.role.arn
  filename = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# add api gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "${local.resourceName}-api-gw"
}

resource "aws_api_gateway_resource" "test" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id = aws_api_gateway_rest_api.api.root_resource_id
  path_part = "test"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.test.id
  http_method = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.Content-Type" = true
  }
}

#  this code block creates a new API Gateway integration that responds to
#   the specified HTTP method on the specified resource, calls the specified 
#   Lambda function when invoked, and uses a Lambda proxy integration.

resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.api_method.http_method
  integration_http_method = "GET"
  type = "AWS_PROXY"
  uri = aws_lambda_function.lam.invoke_arn
  credentials = aws_iam_role.role.arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.api_integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "dev"
}

# resource "aws_api_gateway_stage" "api_stage" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   stage_name = aws_api_gateway_deployment.api_deployment.stage_name
#   deployment_id = aws_api_gateway_deployment.api_deployment.id
# }

resource "aws_lambda_permission" "api_lambda_permission" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lam.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}



# Create the IAM role
resource "aws_iam_role" "role" {
  name = "${local.resourceName}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com", 
          "apigateway.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create the policy
resource "aws_iam_policy" "policy" {
  name        = "${local.resourceName}-policy"
  description = "Policy for API Gateway, Lambda, and CloudWatch Logs"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:GetLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:DELETE",
        "apigateway:PATCH"
      ],
      "Resource": "arn:aws:apigateway:*::*/*"
    }
  ]
}
EOF
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "policy-attachment" {
  role = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}