terraform {
  required_version = ">= 1.9.0"

  # Configuración parcial: los valores se pasan con
  #   terraform init -backend-config=backend.hcl
  # (ver backend.hcl.example y el output backend_hcl de bootstrap/).
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}

  # Si es null, se usa la variable de entorno ARM_SUBSCRIPTION_ID (así lo usará CI con OIDC).
  subscription_id = var.subscription_id
}
