# Sistema de Reservas · Infraestructura (Terraform)

Infraestructura como código del [Sistema de Reservas](https://github.com/Andy-752109/sistema-reservas-api): todos los recursos de Azure para los ambientes **Dev** y **Prod** se crean desde este repositorio. El state de Terraform se guarda en un Storage Account de Azure (backend `azurerm`), no en el repo.

| Repositorio | Qué hace |
|---|---|
| **`sistema-reservas-infra`** (este) | **Crea** los recursos de Azure con Terraform. Se aplica pocas veces. |
| [`sistema-reservas-api`](https://github.com/Andy-752109/sistema-reservas-api) | API NestJS. Su pipeline **despliega** la imagen en `api-dev` y, con aprobación, en `api-prod`. Ahí viven los issues del proyecto. |
| [`sistema-reservas-web`](https://github.com/Andy-752109/sistema-reservas-web) | Frontend React. Su pipeline **despliega** en `web-dev` y `web-prod`. |

```
.
├── bootstrap/                 # Se aplica una sola vez: crea el Storage Account del state
├── main.tf                    # Resource Group, ambientes y URLs calculadas
├── app_service.tf             # App Service Plan y las 4 Web Apps (api/web × dev/prod)
├── postgresql.tf              # PostgreSQL Flexible Server con bases dev y prod
├── observability.tf           # Log Analytics y Application Insights por ambiente
├── variables.tf               # Prefijo, regiones, SKUs, etiquetas y Docker Hub
├── outputs.tf                 # URLs y nombres que usan los pipelines y la demo
├── versions.tf                # Versiones de Terraform y providers + backend azurerm
├── terraform.tfvars.example   # Plantilla de valores (copiar a terraform.tfvars)
├── backend.hcl.example        # Plantilla de la configuración del backend
└── .terraform.lock.hcl        # Versiones exactas de los providers (se versiona)
```

Este repo se separó de la carpeta `infra/` del repo de la API conservando su historial.

## Recursos

| Recurso | Configuración |
|---|---|
| Resource Group `reservas-rg` | Metadatos en `centralus`; App Service y APM en `westus3`, PostgreSQL en `centralus` |
| App Service Plan `reservas-plan` | Linux **B1** (1 vCPU, 1.75 GB), compartido por las 4 Web Apps. De aquí salen las métricas de CPU y memoria |
| Web Apps `reservas-{api,web}-{dev,prod}-<sufijo>` | Contenedor de Docker Hub, HTTPS obligatorio, TLS 1.2, FTPS apagado, Always On. La API tiene health check en `/health` |
| PostgreSQL Flexible Server (`centralus`) | Versión 16, **B1ms**, 32 GB, respaldos de 7 días. Bases `reservas_dev` y `reservas_prod`. Conexión con `sslmode=require` |
| Log Analytics | 30 días de retención, tope de 1 GB al día |
| Application Insights | Uno por ambiente, basado en el workspace. La API distingue el ambiente con `OTEL_SERVICE_NAME` (`api-dev`, `api-prod`) |

Terraform genera y entrega como *app settings* la contraseña de PostgreSQL (`DATABASE_URL`), un `JWT_SECRET` por ambiente y la cadena de Application Insights. Ningún secreto está escrito en el repo.

## Decisiones de costo y de diseño

El proyecto es académico: un solo usuario a la vez y sin tráfico real. Se eligió lo mínimo que cumple los requisitos, y cada decisión dice qué cambiaría en producción.

| Decisión | Por qué | En producción |
|---|---|---|
| **Un App Service Plan B1 para las 4 apps** | B1 es el plan más barato con contenedores, Always On y health check. F1 (gratis) no tiene Always On: la app se duerme y tarda en responder en la demo | Prod en su propio plan Standard o Premium, aislado de Dev y con autoescalado |
| **Un servidor PostgreSQL con dos bases** (`reservas_dev`, `reservas_prod`) | Dev y Prod quedan aislados a nivel base de datos sin pagar dos servidores | Un servidor por ambiente |
| **Dev y Prod comparten el usuario administrador de PostgreSQL** | Consecuencia de usar un solo servidor | Un usuario por base, con permisos mínimos |
| **Regla de firewall `0.0.0.0`** | Es la regla especial de Azure que permite servicios de Azure. Permite conexiones desde **cualquier** servicio de Azure, no solo las nuestras; la contraseña y TLS siguen siendo obligatorios | Red privada (VNet integration + private endpoint) |
| **Recursos en West US 3** | La suscripción tenía cuota 0 de App Service B1 en Central US, incluso como pay-as-you-go; en West US 3 sí hay. Además está más cerca de Guadalajara | — |
| **Resource Group en Central US** | Su región solo guarda metadatos; cambiarla obliga a recrear el grupo, y Azure lo bloquea porque contiene un recurso que crea solo (Application Insights Smart Detection) | — |
| **PostgreSQL en Central US** | West US 3 rechazó B1ms con `SkuNotAvailable` (falta de capacidad para la suscripción), aunque la consulta de SKUs lo mostraba disponible. En Central US sí se crea. La API consulta la base desde otra región: unos 35 ms más por consulta, imperceptible para un usuario | Base y API en la misma región |
| **Nombres con la región** (`reservas-pg-centralus-…`) | Azure no deja reutilizar en el mismo grupo un nombre que existió en otra región, aunque ya esté borrado | — |
| **Tope de 1 GB al día en Log Analytics** | Un error en bucle no puede consumir el crédito | Tope según el volumen esperado |

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
- Una suscripción de Azure con permiso de Owner o Contributor y cuota de App Service B1 en la región elegida

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

## 3. Variables

```bash
cp terraform.tfvars.example terraform.tfvars   # ignorado por git
```

| Variable | Por defecto | Para qué |
|---|---|---|
| `dockerhub_usuario` | *(obligatoria)* | Usuario de Docker Hub de las imágenes `reservas-api` y `reservas-web` |
| `prefijo` | `reservas` | Prefijo de todos los nombres |
| `location` | `westus3` | Región de los recursos |
| `postgres_location` | `centralus` | Región de PostgreSQL |
| `resource_group_location` | `centralus` | Región del Resource Group |
| `app_service_sku` | `B1` | SKU del App Service Plan |
| `postgres_sku` | `B_Standard_B1ms` | SKU de PostgreSQL |
| `postgres_version` | `16` | Versión de PostgreSQL |
| `postgres_storage_mb` | `32768` | Almacenamiento de PostgreSQL |
| `subscription_id` | `ARM_SUBSCRIPTION_ID` | Suscripción de Azure |
| `tags` | `proyecto`, `gestionado` | Etiquetas comunes |

## 4. Plan y apply

```bash
terraform fmt -recursive
terraform validate
terraform plan -out tfplan      # revisar qué se crea, cambia o destruye
terraform apply tfplan          # aplica exactamente ese plan
terraform output                # URLs de las 4 Web Apps y nombres para los pipelines
```

| Output | Contenido |
|---|---|
| `url_api`, `url_web` | URL pública de cada Web App por ambiente |
| `nombre_web_app_api`, `nombre_web_app_web` | Nombres que usan los pipelines de CD en `azure/webapps-deploy` |
| `postgres_servidor` | Host de PostgreSQL |
| `application_insights` | Recurso de APM por ambiente |
| `resource_group` | Resource Group del proyecto |

Las Web Apps arrancan con la imagen `latest`. Los pipelines de CD cambian la imagen al tag del SHA en cada despliegue; Terraform ignora ese cambio (`ignore_changes`) para no regresar la app a `latest` en el siguiente `apply`.

## 5. Después de la entrega

Para dejar de generar costos:

```bash
terraform destroy               # borra reservas-rg y todo lo que contiene
```

El backend del state (`bootstrap/`) tiene `prevent_destroy`: si también se quiere borrar, hay que quitar esa línea y correr `terraform destroy` en `bootstrap/`.

## Flujo de trabajo

- Todo cambio entra por PR hacia `develop` (protegida, 1 aprobación, check **Formato y validación** obligatorio y auto-merge al aprobarse). Las liberaciones van de `develop` a `main`.
- El workflow **Terraform** corre en cada PR: `terraform fmt -check` y `terraform validate`, sin credenciales de Azure.
- El plan y el apply contra Azure los ejecuta DevOps desde su terminal, después de fusionar.
- Los issues viven en el repo de la API: en los PR se cierran con `Closes Andy-752109/sistema-reservas-api#<n>`.
