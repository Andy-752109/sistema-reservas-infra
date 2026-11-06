variable "subscription_id" {
  description = "ID de la suscripción de Azure. Si se omite, se usa ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "location" {
  description = "Región de Azure para los recursos del state."
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Resource Group exclusivo del state de Terraform (separado de reservas-rg)."
  type        = string
  default     = "reservas-tfstate-rg"
}

variable "storage_account_prefix" {
  description = "Prefijo del Storage Account. Se le agrega un sufijo aleatorio para que el nombre sea único en Azure."
  type        = string
  default     = "streservastf"

  validation {
    condition     = can(regex("^[a-z0-9]{3,18}$", var.storage_account_prefix))
    error_message = "Solo minúsculas y números, de 3 a 18 caracteres (el sufijo agrega 6)."
  }
}

variable "container_name" {
  description = "Contenedor de blobs donde se guardan los archivos de state."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Etiquetas aplicadas a los recursos."
  type        = map(string)
  default = {
    proyecto   = "sistema-reservas"
    componente = "terraform-state"
    gestionado = "terraform"
  }
}
