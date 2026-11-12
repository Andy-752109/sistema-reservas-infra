# Variables base. El issue #45 agrega prefijo, SKUs y terraform.tfvars.example.

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

variable "resource_group_location" {
  description = "Región del Resource Group. Solo guarda metadatos; cambiarla obliga a recrear el grupo."
  type        = string
  default     = "centralus"
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
