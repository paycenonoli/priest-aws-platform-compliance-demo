resource "aws_s3_bucket" "compliance_demo" {
  bucket = "priest-platform-compliance-demo-417521971848"

  tags = {
    Name        = "platform-compliance-demo"
    Environment = var.environment
    # Owner       = "Platform-Team"
  }
}
