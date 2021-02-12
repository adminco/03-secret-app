variable "bucket_name" {
  description = "This is the name of the s3 bucket/app"
  type        = string
}

variable "cf_secret" {
  description = "This is the secret used by Cloudfront to connect to S3 website"
  type        = string
  default     = "gcf745MeNRzhp9Y"
}
