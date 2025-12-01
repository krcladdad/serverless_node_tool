variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "docker_image" {
  description = "Docker image to run on the instance (user-data)"
  type        = string
  default     = "your/image:latest"
}

variable "key_name" {
  description = "Key pair name to create (used for SSH)."
  type        = string
  default     = "serverless.pem"
}

variable "open_all_inbound" {
  description = "If true, opens the security group to all inbound traffic (dangerous, for dev/testing only)."
  type        = bool
  default     = false
}