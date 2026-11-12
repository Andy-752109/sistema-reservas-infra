# APM: un workspace de Log Analytics compartido y un Application Insights por
# ambiente, para que en el portal Dev y Prod se vean por separado. La API además
# distingue el ambiente con OTEL_SERVICE_NAME (api-dev / api-prod).
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefijo}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  # Tope diario de ingesta para que un error en bucle no consuma el crédito.
  daily_quota_gb = 1
  tags           = var.tags
}

resource "azurerm_application_insights" "ambiente" {
  for_each = local.ambientes

  name                = "${local.prefijo}-appi-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "Node.JS"
  tags                = var.tags
}
