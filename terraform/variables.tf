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

variable "regional_vm_networks" {
  description = "Additional regional VM networks to peer with the core VNet"
  type = map(object({
    location           = string
    address_space      = list(string)
    vm_subnet_prefixes = list(string)
  }))
  default = {}
}

variable "admin_sql_user" {
  type    = string
  default = "euphrosyne"
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

variable "key_vault_secret_manager_object_ids" {
  description = "Entra object IDs of the people and CI identities that manage Key Vault secrets. Listed explicitly so that running Terraform as another identity does not replace the access policy."
  type        = list(string)

  validation {
    condition     = length(var.key_vault_secret_manager_object_ids) > 0
    error_message = "At least one object ID must manage the Key Vault secrets."
  }
}
