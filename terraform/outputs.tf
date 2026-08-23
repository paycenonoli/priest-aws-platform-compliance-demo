output "bucket_name" {
  description = "Name of the compliance demo bucket"
  value       = aws_s3_bucket.compliance_demo.bucket
}
