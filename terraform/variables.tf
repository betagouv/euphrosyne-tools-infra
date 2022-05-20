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
