provider "aws" {
  region = var.region

  default_tags {
    tags = {
      stack_name              = local.stack_tag
      archer-cost-center      = "391111"
      archer-stack-type       = "dev"
      archer-stack-name       = local.stack_tag
      archer-application-role = "dev"
      archer-owner            = "douglas.heller@archerirm.com"
      archer-region           = var.region
    }
  }
}
