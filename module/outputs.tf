output "cloudfront-domain-name" {
  description = "This is the url to access the application"
  value = aws_cloudfront_distribution.secret-app-distribution.domain_name 
}
