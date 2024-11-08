terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }

  # Update this block with the location of your terraform state file
  backend "azurerm" {
    resource_group_name  = "rg-test-ae-compute-002"
    storage_account_name = "devboxscriptssa"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# User Managed Identity
resource "azurerm_user_assigned_identity" "userIdentity" {
  location            = data.azurerm_resource_group.rg.location
  name                = var.devCenterUserIdentity
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "userIdentityRoleAssignment" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.userIdentity.principal_id
}

# Dev Center
resource "azurerm_dev_center" "devCenter" {
  location            = data.azurerm_resource_group.rg.location
  name                = var.devCenterName
  resource_group_name = data.azurerm_resource_group.rg.name
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.userIdentity.client_id]
  }
}