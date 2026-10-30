
variable "aws_region" {
  description = "AWS region for project resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "edge-cdn"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "lambda_memory_size" {
  description = "Memory allocated to image processing Lambda"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Maximum Lambda execution time in seconds"
  type        = number
  default     = 30
}
