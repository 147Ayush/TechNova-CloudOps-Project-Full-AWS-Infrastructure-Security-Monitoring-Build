variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "technova-cloud"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "instance_type_web" {
  type    = string
  default = "t3.micro"
}

variable "db_instance_class" {
  type    = string
  default = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "technova_db"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type    = string
  description = "Set this in a secure way (tfvars / env)."
  default = "ChangeMe123!" 
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to ssh into the web instance (if needed). Set to your IP or 0.0.0.0/0 for open - not recommended."
  type = string
  default = "0.0.0.0/0"
}
