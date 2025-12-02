provider "aws" {
  region = "us-east-1"
}

# -------------------------------
# S3 Bucket
# -------------------------------
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.s3_bucket_name
}

# -------------------------------
# DynamoDB Table
# -------------------------------
resource "aws_dynamodb_table" "note_table" {
  name         = var.note_table_name
  billing_mode = "pay_per_request"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "contactus_table" {
  name         = var.contactus_table_name
  billing_mode = "pay_per_request"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}


# -------------------------------
# IAM Role for Lambda
# -------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach AWS Managed Policies
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_admin" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# -------------------------------
# Lambda Functions
# -------------------------------
resource "aws_lambda_function" "contact_us" {
  function_name     = "ContactUsLambda"
  handler           = "contact_us.lambda_handler"
  runtime           = "python3.9"
  role              = aws_iam_role.lambda_role.arn
  filename          = "lambda/contact-page-info.zip"
  source_code_hash  = filebase64sha256("lambda/contact-page-info.zip")
}

resource "aws_lambda_function" "notes" {
  function_name     = "NotesLambda"
  handler           = "notes.lambda_handler"
  runtime           = "python3.9"
  role              = aws_iam_role.lambda_role.arn
  filename          = "lambda/flaskNoteTools.zip"
  source_code_hash  = filebase64sha256("lambda/flaskNoteTools.zip")
}

resource "aws_lambda_function" "upload" {
  function_name     = "UploadLambda"
  handler           = "upload.lambda_handler"
  runtime           = "python3.9"
  role              = aws_iam_role.lambda_role.arn
  filename          = "lambda/upload-image.zip"
  source_code_hash  = filebase64sha256("lambda/upload-image.zip")
}


# -------------------------------
# API Gateway REST API
# -------------------------------
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "MyLambdaAPI"
  description = "API Gateway for multiple Lambda functions"
}

# -------------------------------
# Create Resources for Each Route
# -------------------------------
resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "store-contactUs"
}

resource "aws_api_gateway_resource" "notes_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "note"
}

resource "aws_api_gateway_resource" "upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "upload-image"
}

# -------------------------------
# Methods for Each Resource
# -------------------------------
resource "aws_api_gateway_method" "contact_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "notes_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.notes_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "upload_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "POST"
  authorization = "NONE"
}


# GET method for notes
resource "aws_api_gateway_method" "notes_get" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.notes_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# DELETE method for notes
resource "aws_api_gateway_method" "notes_delete" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.notes_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
}


# PUT method for notes (edit)
resource "aws_api_gateway_method" "notes_put" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.notes_resource.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "upload_get" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "GET"
  authorization = "NONE"
}


# -------------------------------
# Integrations with Lambda
# -------------------------------
resource "aws_api_gateway_integration" "contact_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.contact_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact_us.invoke_arn
}

resource "aws_api_gateway_integration" "notes_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.notes_resource.id
  http_method             = aws_api_gateway_method.notes_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notes.invoke_arn
}

resource "aws_api_gateway_integration" "upload_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.upload_resource.id
  http_method             = aws_api_gateway_method.upload_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload.invoke_arn
}


resource "aws_api_gateway_integration" "notes_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.notes_resource.id
  http_method             = aws_api_gateway_method.notes_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notes.invoke_arn
}

resource "aws_api_gateway_integration" "notes_delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.notes_resource.id
  http_method             = aws_api_gateway_method.notes_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notes.invoke_arn
}


resource "aws_api_gateway_integration" "notes_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.notes_resource.id
  http_method             = aws_api_gateway_method.notes_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notes.invoke_arn
}


resource "aws_api_gateway_integration" "upload_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.upload_resource.id
  http_method             = aws_api_gateway_method.upload_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload.invoke_arn
}


# -------------------------------
# Lambda Permissions for API Gateway
# -------------------------------
resource "aws_lambda_permission" "contact_permission" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_us.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "notes_permission" {
  statement_id  = "AllowAPIGatewayInvokeNotes"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "upload_permission" {
  statement_id  = "AllowAPIGatewayInvokeUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}

# -------------------------------
# Deployment and Stage
# -------------------------------
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.contact_integration,
    aws_api_gateway_integration.notes_integration,
    aws_api_gateway_integration.upload_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.my_api.id

  # Force redeployment when integrations change
  triggers = {
    redeploy = timestamp()
  }
}

# Stage
resource "aws_api_gateway_stage" "dev_stage" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "dev"
}

#-------------------------------
# Secrets Manager for Application Secrets
#-------------------------------
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "my-app-secrets"
  description = "Secrets for Flask app"
}

# Store secrets as key-value pairs in JSON format
resource "aws_secretsmanager_secret_version" "app_secret_version" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    FLASK_SECRET_KEY            = "supersecret"
    AWS_ACCESS_KEY              = "AKIA3FSTKUYAQA6NJBUX"
    AWS_SECURITY_ACCESS_KEY     = "Kz59zQGWnDOQL3ppr7Z9kiHdbsNdgVRCVujC1E0m"
    region                      = var.region
    AWS_S3_BUCKET               = aws_s3_bucket.my_bucket.bucket
    AWS_DYNAMO_TABLE_NOTES      = var.note_table_name
    AWS_DYNAMO_TABLE_CONTACTUS  = var.contactus_table_name
    API_BASE                    = "https://${aws_api_gateway_rest_api.my_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev_stage.stage_name}"
    API_BASE_IMAGE              = "https://${aws_api_gateway_rest_api.image_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev_stage.stage_name}"
    API_BASE_CONTACT            = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev_stage.stage_name}"
    DOCKER_USERNAME             = "kladdad"
    DOCKER_PASSWORD             = "Kanchetan@143"
  })
}


# -------------------------------
# IAM Role for EC2 to access Secrets Manager
# -------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-secrets-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_secrets_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------------
# Security Group
# -------------------------------
resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow HTTP, SSH, and Flask port"
  vpc_id      = aws_instance.flask_serverless_app.vpc_security_group_ids[0]

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask App"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  # Egress rules (allow all outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
# -----------------
# create pem file for ssh and attchh to ec2
# -----------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# -------------------------------
# create ec2 instance for flask serverless app
# -------------------------------

resource "aws_instance" "flask_serverless_app" {
  ami           = "ami-0fa3fe0fa7920f68e" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  
  
  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y docker
                #Start and enable Docker
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker ec2-user                
                
                
                # Fetch Docker Hub credentials from AWS Secrets Manager
                 SECRET=$(aws secretsmanager get-secret-value --secret-id my-docker-credentials     --query SecretString --output text)
                  USERNAME=$(echo $SECRET | jq -r .DOCKER_USERNAME)
                  PASSWORD=$(echo $SECRET | jq -r .DOCKER_PASSWORD)

                
                
                # Login to Docker Hub
                echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin

                # Pull your Docker image
                docker pull $USERNAME/flask-app:latest


                
                # Run the container on port 5000
                docker run -d -p 5000:5000 --name flask-app $USERNAME/flask-app:latest
                EOF
              
  tags = {
    Name = "FlaskServerlessAppInstance"
  }
}



