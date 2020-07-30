variable "name" {
  default     = "Default"
  type        = string
  description = "Name of the VPC"
}

variable "environment" {
  type        = string
  description = "Name of environment: ex. stg, prod, dev"
}

variable "region" {
  default     = "us-east-1"
  type        = string
  description = "Region of the VPC"
}

variable "key_name" {
  type        = string
  description = "EC2 Key pair name"
}
variable "instance_type" {
  description = "Instance type for Panorama"
  default     = "m4.2xlarge"
}

variable "panorama_version" {
  description = "Mainline version for Panorama. Does not define a specific release number."
  default     = "9.1"
}

variable enable_ha {
  description = "If enabled, deploy the resources for a HA pair of Panoramas instead of a single Panorama"
  type = bool
  default = true
}

variable "cidr_block" {
  default     = "10.0.0.0/16"
  type        = string
  description = "CIDR block for the VPC"
}

variable "mgmt_subnet" {
  description = "IP and mask of the network that will be accessing Panorama"
  type        = string
}