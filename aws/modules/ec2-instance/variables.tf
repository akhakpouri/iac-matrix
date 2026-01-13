variable "ami_id" {
  type        = string
  description = "AMI id for instance."
}

variable "instance_name" {
  type        = string
  description = "Name of the EC2 instance."
}

variable "project_name" {
  type        = string
  description = "Name of the example project."

  default = "terraform-init"
}

variable "instance_type" {
  description = "type of the instance. It's ec2"
  type        = string
  default     = "t2.micro"
}
