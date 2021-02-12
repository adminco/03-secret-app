output "cdn" {
 description = "This is the cdn url"
 value       = module.secret-app.cloudfront-domain-name
}
