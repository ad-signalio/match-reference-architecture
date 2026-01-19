terraform {
  backend "s3" {
    bucket       = "s3-terraform-state-example"
    key          = "environments/example/s3/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true

  }
}
