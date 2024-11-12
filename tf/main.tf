terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
    azapi = {
      source = "azure/azapi"
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

resource "azurerm_dev_center_gallery" "devCenterGallery" {
  dev_center_id     = azurerm_dev_center.devCenter.id
  shared_gallery_id = azurerm_shared_image_gallery.azureGallery.id
  name              = var.galleryName
}

resource "azurerm_shared_image" "customImageDefinition" {
  name                = var.imageDefinitionName
  gallery_name        = azurerm_shared_image_gallery.azureGallery.name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Windows"

  identifier {
    publisher = var.imageDefinitionName
    offer     = var.imageDefinitionName
    sku       = "1-0-0"
  }
  hyper_v_generation           = "V2"
  architecture                 = "x64"
  trusted_launch_enabled       = true
  min_recommended_vcpu_count   = 1
  max_recommended_vcpu_count   = 16
  min_recommended_memory_in_gb = 1
  max_recommended_memory_in_gb = 32
}

resource "azapi_resource" "imageTemplate" {
  type      = "Microsoft.VirtualMachineImages/imageTemplates@2024-02-01"
  name      = var.imageTemplateName
  location  = data.azurerm_resource_group.rg.location
  parent_id = data.azurerm_resource_group.rg.id
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.userIdentity.id]
  }
  body = jsonencode({
    properties = {
      autoRun = {
        state = "string"
      }
      buildTimeoutInMinutes = 0
      customize = [
        {
          destination    = "C:/scheduler.ps1"
          name           = "Upload Create Scheduled Task Script"
          sha256Checksum = "ff06220855bbb7448ed4d5e99dca1c8a52fbdf27d179b90c3a96b570231a1d9e"
          sourceUri      = "https://raw.githubusercontent.com/artagame/devboxpoc/refs/heads/main/scheduler.ps1"
          type           = "File"
        },
        {
          destination    = "C:/installVSCodeExtensionsAndCloneRepo.ps1"
          name           = "Upload Install VS Code Extensions and Clone Repo Script"
          sha256Checksum = "8448d9fb641044f267a83c17bb44c43984fd76eebd586dbb5ccac8380ea113f7"
          sourceUri      = "https://raw.githubusercontent.com/artagame/devboxpoc/refs/heads/main/installVSCodeExtensionsAndCloneRepo.ps1"
          type           = "File"
        },
        {
          inline = [
            "# Set Execution Policy to Bypass for the current process\nSet-ExecutionPolicy Bypass -Scope Process -Force\n\n# Set security protocol to support TLS 1.2\n[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072\n\n# Install Chocolatey\niex ((New-Object System.Net.WebClient).DownloadString(\"https://community.chocolatey.org/install.ps1\"))\n\n# Install Git",
            "Azure CLI",
            "and Visual Studio Code\nchoco install -y git\nchoco install -y azure-cli\nchoco install -y vscode\nchoco install -y nodejs\n\ncd \"C:\\\"\nmkdir \"Workspaces\"\nwsl.exe --update\npowershell.exe -File 'C:\\scheduler.ps1'"
          ]
          name        = "Choco Tasks and Trigger Create Scheduled Task Script"
          runAsSystem = false,
          runElevated = false
          type        = "PowerShell"
        }
      ]
      distribute = [
        {
          artifactTags      = {}
          excludeFromLatest = false
          galleryImageId    = azurerm_shared_image_gallery.azureGallery.id
          runOutputName     = "runOutputImageVersion"
          type              = "SharedImage"
        }
      ]
      source = {
        type      = "PlatformImage"
        offer     = "visualstudioplustools"
        publisher = "microsoftvisualstudio"
        sku       = "vs-2022-ent-general-win11-m365-gen2"
        version   = "latest"
      }
      vmProfile = {
        osDiskSizeGB = 127
        vmSize       = "Standard_DS1_v2"
      }
    }
  })
}