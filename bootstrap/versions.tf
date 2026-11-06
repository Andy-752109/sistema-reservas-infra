terraform {
  required_version = ">= 1.9.0"

  # Sin bloque backend: este módulo crea el backend remoto, así que su propio
  # state es local (bootstrap/terraform.tfstate, ignorado por git).

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

  # Si es null, se usa la variable de entorno ARM_SUBSCRIPTION_ID.
  subscription_id = var.subscription_id
}
