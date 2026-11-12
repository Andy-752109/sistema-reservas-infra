# Un solo servidor PostgreSQL Flexible (B1ms) con una base por ambiente.
# Dev y Prod quedan aislados a nivel de base de datos sin pagar dos servidores.

# Sin caracteres especiales: la contraseña va dentro de DATABASE_URL y así no
# hace falta codificarla para la URL.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "main" {
  # El nombre es global en *.postgres.database.azure.com.
  name                = "${local.prefijo}-pg-${random_string.sufijo.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version    = "16"
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  administrator_login    = "reservasadmin"
  administrator_password = random_password.postgres.result

  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true

  lifecycle {
    # Azure asigna la zona al crear el servidor; sin esto, cada plan querría cambiarla.
    ignore_changes = [zone]
  }

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "ambiente" {
  for_each = local.ambientes

  name      = "reservas_${each.key}"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# 0.0.0.0 es la regla especial de Azure que permite servicios de Azure (las Web Apps).
resource "azurerm_postgresql_flexible_server_firewall_rule" "servicios_azure" {
  name             = "permitir-servicios-azure"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

locals {
  database_url = {
    for amb, _ in local.ambientes : amb => format(
      "postgresql://%s:%s@%s:5432/%s?sslmode=require&schema=public",
      azurerm_postgresql_flexible_server.main.administrator_login,
      random_password.postgres.result,
      azurerm_postgresql_flexible_server.main.fqdn,
      azurerm_postgresql_flexible_server_database.ambiente[amb].name,
    )
  }
}
