variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "euphrosyne-01-fixlab"
}

variable "location" {
  description = "Where to host all resources"
  type        = string
  default     = "westeurope"
}

variable "prefix" {
  type    = string
  default = "euphrosyne-01"
}

variable "admin_sql_user" {
  type    = string
  default = "euphrosyne"
}

variable "bastion_user" {
  type    = string
  default = "euphrosyne-bastion"
}

variable "bastion_password" {
  type      = string
  sensitive = true
}

variable "euphrosyne_tools_url" {
  description = "URL of Euphrosyne Tools service. Example : https://euphrosyne-tools-api-staging.osc-fr1.scalingo.io"
  type        = string
}

variable "image_registry_credential_username" {
  description = "value of the username for the docker image registry"
  type        = string
}

variable "image_registry_credential_password" {
  description = "value of the access token for the docker image registry. Can be generated at https://app.docker.com/settings/personal-access-tokens"
  type        = string
  sensitive   = true
}
