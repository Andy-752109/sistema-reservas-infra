output "resource_group_name" {
  description = "Resource Group del state."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Storage Account del state."
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Contenedor del state."
  value       = azurerm_storage_container.tfstate.name
}

output "backend_hcl" {
  description = "Contenido listo para copiar a infra/backend.hcl."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "reservas.tfstate"
  EOT
}
