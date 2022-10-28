variable "prefix" {}

variable "region" {}

variable "apitype" {}

variable "name" {}

variable "api_gateway_source_arn" {}

variable "layers" {}

variable "kms_key_id" {}

variable "environment_variables" {}

variable "additional_policies" {
  default = []
}

variable "handler" {}
