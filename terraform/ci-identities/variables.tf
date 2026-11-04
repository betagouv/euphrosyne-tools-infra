variable "resource_group_name" {
  description = "Resource group holding the CI identities, next to the Terraform state"
  type        = string
  default     = "Euphrosyne_tfstate"
}

variable "github_repository" {
  description = "GitHub repository, as owner/name, whose workflows may use the identities"
  type        = string
  default     = "betagouv/euphrosyne-tools-infra"
}
