# Sistema de Reservas · Infraestructura (Terraform)

Infraestructura como código del [Sistema de Reservas](https://github.com/Andy-752109/sistema-reservas-api): todos los recursos de Azure para los ambientes **Dev** y **Prod** se crean desde este repositorio. El state de Terraform se guarda en un Storage Account de Azure (backend `azurerm`), no en el repo.

| Repositorio | Qué hace |
|---|---|
| **`sistema-reservas-infra`** (este) | **Crea** los recursos de Azure con Terraform. Se aplica pocas veces. |
| [`sistema-reservas-api`](https://github.com/Andy-752109/sistema-reservas-api) | API NestJS. Su pipeline **despliega** la imagen en `api-dev` y, con aprobación, en `api-prod`. Ahí viven los issues del proyecto. |
| [`sistema-reservas-web`](https://github.com/Andy-752109/sistema-reservas-web) | Frontend React. Su pipeline **despliega** en `web-dev` y `web-prod`. |

```
.
├── bootstrap/            # Se aplica una sola vez: crea el Storage Account del state
├── versions.tf           # Versiones de Terraform y providers + backend azurerm
├── variables.tf          # Variables (región, etiquetas, suscripción)
├── backend.hcl.example   # Plantilla de la configuración del backend
└── .terraform.lock.hcl   # Versiones exactas de los providers (se versiona)
```

Los recursos de la aplicación se agregan en los issues #42 (App Service), #43 (PostgreSQL) y #44 (Application Insights); las variables por ambiente y los outputs, en el #45. Este repo se separó de la carpeta `infra/` del repo de la API conservando su historial.

## State remoto

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

```bash
az login
az account show --query "{nombre:name, id:id}" -o table
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# PowerShell: $env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

## 1. Crear el backend del state (una sola vez)

Lo hace solo DevOps (Andy). Si el Storage Account ya existe, salta al paso 2.

```bash
cd bootstrap
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

El state de `bootstrap/` es local (`bootstrap/terraform.tfstate`) y no se sube a git. Si se pierde, no pasa nada con el backend; se puede recuperar con `terraform import`.

## 2. Configurar el backend e inicializar

```bash
terraform -chdir=bootstrap output -raw backend_hcl > backend.hcl
# PowerShell (ASCII evita que se guarde con codificación UTF-16):
# terraform -chdir=bootstrap output -raw backend_hcl | Out-File -Encoding ascii backend.hcl

terraform init -backend-config=backend.hcl
```

Quien no corrió el bootstrap copia `backend.hcl.example` a `backend.hcl` y pone el nombre real del Storage Account. Lo puede consultar con `az storage account list -g reservas-tfstate-rg --query "[].name" -o tsv`.

## 3. Uso diario

```bash
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

## Flujo de trabajo

- Todo cambio entra por PR hacia `develop` (protegida, 1 aprobación, auto-merge al aprobarse). Las liberaciones van de `develop` a `main`.
- El workflow **Terraform** corre en cada PR: `terraform fmt -check` y `terraform validate`, sin credenciales de Azure.
- El plan y el apply contra Azure los ejecuta DevOps desde su terminal, después de fusionar.
- Los issues viven en el repo de la API: en los PR se cierran con `Closes Andy-752109/sistema-reservas-api#<n>`.
