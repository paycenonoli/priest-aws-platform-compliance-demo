terraform {
  backend "s3" {
    bucket       = "priest-platform-compliance-tfstate-417521971848"
    key          = "platform-compliance/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
