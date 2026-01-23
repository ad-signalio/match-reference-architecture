module "state_bucket" {
  # source            = "https://github.com/ad-signalio/terraform-utils-private.git//aws/state-bucket?ref=v0.0.5-aws-state-bucket"
  source            = "git::https://github.com/ad-signalio/terraform-utils-private.git//aws/state-bucket?ref=v0.0.5-aws-state-bucket"
  aws_region        = "us-east-1"
  aws_account_name  = "sandbox"
  state_bucket_name = "example"
}
