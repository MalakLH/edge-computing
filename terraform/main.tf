terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = ">= 5.40" }
    random  = { source = "hashicorp/random" }
    archive = { source = "hashicorp/archive" }
  }
}
provider "aws" { region = "eu-west-1" }
resource "random_id" "s" { byte_length = 3 }
