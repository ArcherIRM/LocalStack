variable "stack_name" {
  description = "The name of the stack"
  type        = string
  default     = "Archer"
}

variable "region" {
  description = "The AWS region"
  type        = string
  default     = "us-west-2"
}

variable "sa_password" {
  default     = "asdf" # <---------------------------------------------------------------- Change this default value
  description = "Password for the sa user in SQL Server"
  type        = string
  validation {
    condition     = !contains(["ChangeMe123!"], var.sa_password)
    error_message = "Please change the default value for the sa_password variable in variables.tf"
  }
}
