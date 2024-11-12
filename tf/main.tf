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
    identity_ids = [azurerm_user_assigned_identity.userIdentity.id]
  }
}

resource "azurerm_dev_center_catalog" "devCenterCatalogs" {
  name                = "DevBoxQuickStartTasks"
  resource_group_name = data.azurerm_resource_group.rg.name
  dev_center_id       = azurerm_dev_center.devCenter.id
  catalog_github {
    branch            = "main"
    path              = ""
    uri               = "https://github.com/microsoft/devcenter-catalog.git"
    key_vault_key_url = ""
  }
}

resource "azurerm_dev_center_project" "devCenterProject" {
  dev_center_id       = azurerm_dev_center.devCenter.id
  location            = data.azurerm_resource_group.rg.location
  name                = var.projectName
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_shared_image_gallery" "azureGallery" {
  name                = var.galleryName
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  description         = "Test Gallery"
}