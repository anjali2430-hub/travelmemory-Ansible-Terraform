variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for resource names and tags"
  type        = string
  default     = "travelmemory"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet (web server)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block of the private subnet (database server)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AZ for both subnets. Leave empty to use the first AZ of the region."
  type        = string
  default     = ""
}

variable "web_instance_type" {
  description = "Instance type of the web server (React build needs ~1.5 GB RAM; swap is added by Ansible)"
  type        = string
  default     = "t3.small"
}

variable "db_instance_type" {
  description = "Instance type of the MongoDB server"
  type        = string
  default     = "t3.small"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the web server, e.g. \"203.0.113.10/32\". Leave empty to auto-detect your current public IP."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}
