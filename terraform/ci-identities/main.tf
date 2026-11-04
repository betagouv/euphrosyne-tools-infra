terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.44.1"
    }
  }

  backend "azurerm" {
    resource_group_name  = "Euphrosyne_tfstate"
    storage_account_name = "euphrosynetfstate"
    // Kept apart from the environment states so that CI identities cannot
    // write the state that describes them.
    container_name = "tfstate-ci"
    key            = "ci-identities.tfstate"
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

locals {
  // Identity name => GitHub environment allowed to use it.
  identities = {
    "ci-staging"      = "staging"
    "ci-staging-plan" = "staging-plan"
    "ci-prod-plan"    = "production-plan"
    "ci-prod-apply"   = "production"
  }
}

data "azurerm_resource_group" "ci" {
  name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "ci" {
  for_each = local.identities

  name                = each.key
  location            = data.azurerm_resource_group.ci.location
  resource_group_name = data.azurerm_resource_group.ci.name
}

// Only workflow jobs running in the matching GitHub environment get a token for
// the identity. Environment protection rules decide which branches and
// reviewers can reach each environment.
resource "azurerm_federated_identity_credential" "github" {
  for_each = local.identities

  name                = "github-${each.value}"
  resource_group_name = data.azurerm_resource_group.ci.name
  parent_id           = azurerm_user_assigned_identity.ci[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repository}:environment:${each.value}"
}
