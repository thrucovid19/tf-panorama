variable "credentials" {
  default = "~/.aws/credentials"
}

variable "region" {
  description = "EC2 Region for the VPC"
  default     = "us-east-1"
}
