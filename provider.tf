locals {
  stack_tag = "${var.stack_name}-IaC-Mockup"
}

provider "aws" {

  region = var.region

  default_tags {
    tags = {
      stack_name = local.stack_tag
    }
  }

}
