provider "aws" {
  region = "us-east-1"
}

# DynamoDB table
resource "aws_dynamodb_table" "users" {
  name         = "users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_basic_execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_role_policy" "lambda_dynamodb_read" {
  name = "lambda-dynamodb-read"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.users.arn
      }
    ]
  })
}


# Read Lambda code directly from file
data "local_file" "lambda_code" {
  filename = "${path.module}/../lambda/read_table.py"
}

# Package Lambda code into a zip archive automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = data.local_file.lambda_code.filename
  output_path = "${path.module}/read_table_lambda_payload.zip"
}

# Lambda Function
resource "aws_lambda_function" "read_users" {
  function_name = "ReadUsersFunction"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "read_table.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.users.name
    }
  }
}
