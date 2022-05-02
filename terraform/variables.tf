variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "euphrosyne-fixlab"
}

variable "location" {
  description = "Where to host all resources"
  type        = string
  default     = "northeurope"
}
