variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "vpc_id" {
  description = "Existing default VPC"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for Jenkins"
  type        = string
}

variable "instance_type" {
  description = "Jenkins EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Existing EC2 key pair"
  type        = string
}

variable "allowed_cidr" {
  description = "Public IP allowed to access Jenkins and SSH"
  type        = string
}

variable "jenkins_instance_name" {
  description = "Jenkins EC2 instance name"
  type        = string
  default     = "trendstore-jenkins"
}
