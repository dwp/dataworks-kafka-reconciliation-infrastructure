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
