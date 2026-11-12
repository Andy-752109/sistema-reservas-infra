output "resource_group" {
  description = "Resource Group de los recursos del proyecto."
  value       = azurerm_resource_group.main.name
}

output "url_api" {
  description = "URL pública de la API por ambiente."
  value       = { for amb, app in azurerm_linux_web_app.api : amb => "https://${app.default_hostname}" }
}

output "url_web" {
  description = "URL pública del frontend por ambiente."
  value       = { for amb, app in azurerm_linux_web_app.web : amb => "https://${app.default_hostname}" }
}

# Los pipelines de CD (#50, #53) usan estos nombres en azure/webapps-deploy.
output "nombre_web_app_api" {
  description = "Nombre de la Web App de la API por ambiente."
  value       = { for amb, app in azurerm_linux_web_app.api : amb => app.name }
}

output "nombre_web_app_web" {
  description = "Nombre de la Web App del frontend por ambiente."
  value       = { for amb, app in azurerm_linux_web_app.web : amb => app.name }
}

output "postgres_servidor" {
  description = "Host del PostgreSQL Flexible Server (la contraseña solo vive en el state y en DATABASE_URL)."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "application_insights" {
  description = "Recurso de Application Insights por ambiente, para buscarlo en el portal."
  value       = { for amb, ai in azurerm_application_insights.ambiente : amb => ai.name }
}
