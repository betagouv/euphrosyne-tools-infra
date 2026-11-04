output "client_ids" {
  description = "Client IDs to set as AZURE_CLIENT_ID in each GitHub environment"
  value       = { for name, identity in azurerm_user_assigned_identity.ci : name => identity.client_id }
}

output "principal_ids" {
  description = "Object IDs to use in role assignments and Key Vault access policies"
  value       = { for name, identity in azurerm_user_assigned_identity.ci : name => identity.principal_id }
}

output "tenant_id" {
  description = "Tenant ID to set as AZURE_TENANT_ID in GitHub"
  value       = azurerm_user_assigned_identity.ci["ci-staging"].tenant_id
}
