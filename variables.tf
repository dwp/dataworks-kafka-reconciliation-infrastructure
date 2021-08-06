variable "assume_role" {
  type        = string
  default     = "ci"
  description = "IAM role assumed by Concourse when running Terraform"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "glue_launcher_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

variable "ecs_hardened_ami_id" {
  description = "The AMI ID of the latest/pinned Hardened AMI AL2 Image"
  type        = string
}

variable "ami_id" {
  default = "ami-066f41adad7527ef6"
}

variable "image_version" {
  description = "Container tag values."
  default = {
    kafka-reconciliation = "0.0.4"
  }
}
variable "athena_reconciliation_launcher_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

variable "costcode" {
  type    = string
  default = ""
}
