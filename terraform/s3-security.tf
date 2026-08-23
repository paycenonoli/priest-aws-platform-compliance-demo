# resource "aws_s3_bucket_public_access_block" "compliance_demo" {
#   bucket = aws_s3_bucket.compliance_demo.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

resource "aws_s3_bucket_versioning" "compliance_demo" {
  bucket = aws_s3_bucket.compliance_demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance_demo" {
  bucket = aws_s3_bucket.compliance_demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
