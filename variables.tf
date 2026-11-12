variable "subscription_id" {
  description = "ID de la suscripción de Azure. Si se omite, se usa ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "location" {
  description = "Región de Azure de los recursos del proyecto (App Service, PostgreSQL y APM)."
  type        = string
  # West US 3: la suscripción no tiene cuota de App Service B1 en Central US.
  default = "westus3"
}

variable "postgres_location" {
  description = "Región del PostgreSQL Flexible Server."
  type        = string
  # West US 3 rechaza B1ms con SkuNotAvailable para esta suscripción; Central US sí lo tiene.
  default = "centralus"
}

variable "resource_group_location" {
  description = "Región del Resource Group. Solo guarda metadatos; cambiarla obliga a recrear el grupo."
  type        = string
  default     = "centralus"
}

variable "prefijo" {
  description = "Prefijo de los nombres de los recursos (reservas-rg, reservas-plan, reservas-api-dev-…)."
  type        = string
  default     = "reservas"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.prefijo))
    error_message = "Solo minúsculas y números, de 3 a 12 caracteres, empezando con letra."
  }
}

variable "app_service_sku" {
  description = "SKU del App Service Plan Linux que comparten las 4 Web Apps."
  type        = string
  # El más barato con contenedores, Always On y health check.
  default = "B1"
}

variable "postgres_sku" {
  description = "SKU del PostgreSQL Flexible Server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  description = "Versión mayor de PostgreSQL (la misma que docker-compose y el CI)."
  type        = string
  default     = "16"
}

variable "postgres_storage_mb" {
  description = "Almacenamiento del servidor PostgreSQL en MB."
  type        = number
  default     = 32768
}

variable "tags" {
  description = "Etiquetas comunes para todos los recursos."
  type        = map(string)
  default = {
    proyecto   = "sistema-reservas"
    gestionado = "terraform"
  }
}

variable "dockerhub_usuario" {
  description = "Usuario u organización de Docker Hub donde se publican las imágenes reservas-api y reservas-web."
  type        = string
}
