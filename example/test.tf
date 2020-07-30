terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  version                 = "~> 2.0"
  shared_credentials_file = var.credentials
  region                  = var.region
}

resource "aws_key_pair" "thrucovid19" {
  key_name   = "terraform-key"
  public_key = file("~/.ssh/terraform-key.pub")
}

module "panorama" {
  source         = "github.com/thrucovid19/tf-panorama"
  name           = "Test"
  environment    = "testing"
  enable_ha      = true
  cidr_block     = "172.17.0.0/16"
  key_name       = aws_key_pair.thrucovid19.key_name
  mgmt_subnet    = "192.168.1.0/24"
}

output "primary_eip" {
  value = module.panorama.primary_instance_ip
}

output "secondary_eip" {
  value = module.panorama.secondary_instance_ip
}