#=============DATA SOURCES==========#
#This is for the lamda function index.js file to authenticate users
data "archive_file" "lambda-function-file" {
  type        = "zip"
  source_file = "${path.cwd}/index.js"
  output_path = "${path.cwd}/${var.bucket_name}-auth.zip"
}


#This is the Trusted Entity Lambda role Policy Document
data "aws_iam_policy_document" "lambda-assume-role-policy-json" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "edgelambda.amazonaws.com",
        "lambda.amazonaws.com",
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}


#This is the policy document for the Lambda Edge Function
data "aws_iam_policy_document" "lambda-policy-document-json" {
  statement {
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject","s3:PutObject"]
    resources = ["arn:aws:s3:::*"]
  }
}


#This is the policy document for CloudFront to access s3 bucket
data "aws_iam_policy_document" "cloudfront-policy-document-json" {
  statement {
    sid    = "CloudFrontAccessS3"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.secret-app-bucket.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:UserAgent"
      values   = [var.cf_secret]
    }
  }
}


#=================LOCALS================#
#Define mime types for source code files
locals {
  mime_types = jsondecode(file("${path.cwd}/mime.json"))
}


#=================RESOURCES================#

#Creating the s3 bucket to host static site
resource "aws_s3_bucket" "secret-app-bucket" {
  bucket = var.bucket_name
  acl    = "private"
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  tags = {
    automation = "Terraform"
  }
  force_destroy = true
}

#Uploading source code files to bucket
resource "aws_s3_bucket_object" "objects" {
  bucket        = aws_s3_bucket.secret-app-bucket.id
  for_each      = fileset("${path.cwd}/src/", "*")
  key           = each.value
  source        = "${path.cwd}/src/${each.value}"
  content_type  = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  force_destroy = true
}

#Creating s3 bucket policy for Cloudfront access
resource "aws_s3_bucket_policy" "cloudfront-policy" {
  bucket = aws_s3_bucket.secret-app-bucket.id
  policy = data.aws_iam_policy_document.cloudfront-policy-document-json.json
}


#Creating the cloudFront distribution
resource "aws_cloudfront_distribution" "secret-app-distribution" {
  origin {
    domain_name = aws_s3_bucket.secret-app-bucket.website_endpoint
    origin_id   = "S3-${var.bucket_name}"
    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "User-Agent"
      value = var.cf_secret
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress		   = true
    
    #This is where you link the Lambda function to the cloudFront distribution
    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = aws_lambda_function.secret-app-lambda-edge.qualified_arn
    }
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    automation = "Terraform"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    ssl_support_method             = "sni-only"
  }
}


#Creating an IAM Role for Lambda to Access S3 bucket
resource "aws_iam_role" "iam_for_lambda" {
  name               = "lambda-access-s3-${var.bucket_name}"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role-policy-json.json
}


#Creating an IAM policy for the Lambda function
resource "aws_iam_role_policy" "lambda_execution_role_policy" {
  name   =  "${var.bucket_name}-lambda-policy"
  role   =  aws_iam_role.iam_for_lambda.id
  policy =  data.aws_iam_policy_document.lambda-policy-document-json.json
}


#Creating Lambda Function
resource "aws_lambda_function" "secret-app-lambda-edge" {
  filename         = "${path.cwd}/${var.bucket_name}-auth.zip"
  function_name    = "${var.bucket_name}-auth"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda-function-file.output_base64sha256
  runtime          = "nodejs10.x"
  description      = "This function enables authentication to ${var.bucket_name}"
  memory_size      = 128
  timeout          = 1
  publish          = true

  tags = {
    automation = "Terraform"
  }
}
