# Un solo plan Linux B1 aloja las 4 Web Apps (api y web, dev y prod) para
# mantener el costo bajo.
resource "azurerm_service_plan" "main" {
  name                = "${local.prefijo}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

resource "random_password" "jwt_secret" {
  for_each = local.ambientes

  length  = 48
  special = false
}

resource "azurerm_linux_web_app" "api" {
  for_each = local.ambientes

  name                = local.nombre_api[each.key]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    minimum_tls_version               = "1.2"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5

    application_stack {
      docker_registry_url = "https://index.docker.io"
      docker_image_name   = "${var.dockerhub_usuario}/${local.prefijo}-api:latest"
    }
  }

  app_settings = {
    WEBSITES_PORT                       = "3000"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    NODE_ENV                            = "production"
    AMBIENTE                            = each.value
    # El issue #43 la reemplaza por la cadena del PostgreSQL Flexible Server.
    DATABASE_URL      = ""
    JWT_SECRET        = random_password.jwt_secret[each.key].result
    JWT_EXPIRES_IN    = "1h"
    CORS_ORIGINS      = local.url_web[each.key]
    OTEL_SERVICE_NAME = "api-${each.key}"
    # El pipeline de CD (#50) la actualiza con el SHA desplegado.
    COMMIT_SHA = "pendiente"
  }

  lifecycle {
    # La imagen y su SHA los cambia el CD en cada despliegue; Terraform no los revierte.
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      app_settings["COMMIT_SHA"],
    ]
  }

  tags = var.tags
}

resource "azurerm_linux_web_app" "web" {
  for_each = local.ambientes

  name                = local.nombre_web[each.key]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on           = true
    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"

    application_stack {
      docker_registry_url = "https://index.docker.io"
      docker_image_name   = "${var.dockerhub_usuario}/${local.prefijo}-web:latest"
    }
  }

  # docker/40-generar-config.sh del repo web lee API_URL, AMBIENTE y APP_VERSION.
  app_settings = {
    WEBSITES_PORT                       = "80"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    API_URL                             = local.url_api[each.key]
    AMBIENTE                            = each.value
    # El pipeline de CD del web (#53) la actualiza con la versión desplegada.
    APP_VERSION = "pendiente"
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      app_settings["APP_VERSION"],
    ]
  }

  tags = var.tags
}
