locals {
  # El issue #45 convierte el prefijo y los SKUs en variables.
  prefijo = "reservas"

  # Etiqueta corta de cada ambiente → valor que ve el usuario en el footer del web.
  ambientes = {
    dev  = "DEV"
    prod = "PROD"
  }

  # Los nombres se calculan aquí (y no con default_hostname) porque la API necesita
  # la URL del web para CORS y el web la de la API: con referencias directas entre
  # recursos habría un ciclo.
  nombre_api = { for amb, _ in local.ambientes : amb => "${local.prefijo}-api-${amb}-${random_string.sufijo.result}" }
  nombre_web = { for amb, _ in local.ambientes : amb => "${local.prefijo}-web-${amb}-${random_string.sufijo.result}" }
  url_api    = { for amb, nombre in local.nombre_api : amb => "https://${nombre}.azurewebsites.net" }
  url_web    = { for amb, nombre in local.nombre_web : amb => "https://${nombre}.azurewebsites.net" }
}

# Los nombres de las Web Apps son globales en *.azurewebsites.net.
resource "random_string" "sufijo" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefijo}-rg"
  location = var.location
  tags     = var.tags
}
