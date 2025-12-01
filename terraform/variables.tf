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

variable "key_name" {
  description = "Key pair name to create (used for SSH). If empty, we will create one dynamically."
  type        = string
  default     = "flask_key"
}
variable "docker_image" {
  description = "Docker image to run on EC2"
  type        = string
}
