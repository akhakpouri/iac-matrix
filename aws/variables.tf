variable "instance_name" {
  description = "value of the instance."
  type        = string
  default     = "learn-terraform"
}

variable "instance_type" {
  description = "type of the instance. It's ec2"
  type        = string
  default     = "t2.micro"
}
