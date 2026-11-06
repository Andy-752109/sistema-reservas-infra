# Infraestructura (Terraform)

Recursos de Azure del Sistema de Reservas. El state de Terraform se guarda en un Storage Account de Azure (backend `azurerm`), no en el repo.

```
infra/
├── bootstrap/            # Se aplica una sola vez: crea el Storage Account del state
├── versions.tf           # Versiones de Terraform y providers + backend azurerm
├── variables.tf          # Variables base (región, etiquetas, suscripción)
├── backend.hcl.example   # Plantilla de la configuración del backend
└── .terraform.lock.hcl   # Versiones exactas de los providers (se versiona)
```

| Recurso del state | Valor |
|---|---|
| Resource Group | `reservas-tfstate-rg` (separado de `reservas-rg`) |
| Storage Account | `streservastf` + sufijo aleatorio de 6 caracteres |
| Contenedor | `tfstate` (privado) |
| Archivo de state | `reservas.tfstate` |
| Región | `centralus` |

El Storage Account tiene versionado de blobs y retención de 7 días para recuperar el state si se borra o se corrompe, y `prevent_destroy` para que `terraform destroy` no lo elimine por error.

## Prerrequisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.9 o posterior
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) con sesión iniciada
- Una suscripción de Azure con permiso de Owner o Contributor

```powershell
az login
az account show --query "{nombre:name, id:id}" -o table
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv   # bash: export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## 1. Crear el backend del state (una sola vez)

Lo hace solo DevOps (Andy). Si el Storage Account ya existe, salta al paso 2.

```powershell
cd infra/bootstrap
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

El state de `bootstrap/` es local (`bootstrap/terraform.tfstate`) y no se sube a git. Si se pierde, no pasa nada con el backend; se puede recuperar con `terraform import`.

## 2. Configurar el backend e inicializar

```powershell
cd infra
# PowerShell (ASCII evita que se guarde con codificación UTF-16):
terraform -chdir=bootstrap output -raw backend_hcl | Out-File -Encoding ascii backend.hcl
# bash:
# terraform -chdir=bootstrap output -raw backend_hcl > backend.hcl

terraform init -backend-config=backend.hcl
```

Quien no corrió el bootstrap copia `backend.hcl.example` a `backend.hcl` y pone el nombre real del Storage Account. Lo puede consultar con `az storage account list -g reservas-tfstate-rg --query "[].name" -o tsv`.

## 3. Uso diario

```powershell
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Para validar sin credenciales de Azure, por ejemplo en CI: `terraform init -backend=false` y luego `terraform validate`.

Los recursos del proyecto se agregan en los issues #42 (App Service), #43 (PostgreSQL) y #44 (Application Insights). Las variables por ambiente y los outputs van en el #45.
