#!/usr/bin/env bash
# Crea el administrador y los 6 espacios de ejemplo en la base de un ambiente de Azure,
# con el seed del repo de la API (prisma/seed.ts). Se ejecuta una vez por ambiente,
# después del primer apply.
#
# Uso (macOS, desde la raíz de este repo, con az login y terraform init hechos):
#   1. Copia la contraseña del admin al portapapeles (mínimo 12 caracteres).
#   2. bash scripts/seed-admin.sh dev|prod correo@ejemplo.com
#
# - La contraseña se lee del portapapeles y se borra de él al final; nunca se imprime.
# - DATABASE_URL se toma de la Web App del ambiente; tampoco se imprime.
# - Abre el firewall de PostgreSQL solo para tu IP y lo cierra al terminar, aunque falle.
# - El seed es idempotente: si el admin o los espacios ya existen, los conserva.
# - API_REPO apunta al clon del repo de la API (por defecto, junto a este repo).
set -euo pipefail

AMBIENTE="${1:-}"
CORREO="${2:-}"
case "$AMBIENTE" in dev | prod) ;; *) echo "Uso: bash scripts/seed-admin.sh dev|prod correo"; exit 1 ;; esac
[ -n "$CORREO" ] || { echo "Falta el correo del administrador"; exit 1; }

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API_REPO="${API_REPO:-$RAIZ/../sistema-reservas-api}"
[ -f "$API_REPO/prisma/seed.ts" ] || { echo "No se encontró el repo de la API en $API_REPO (define API_REPO)"; exit 1; }

# Nombres reales desde el state de Terraform: nada queda fijo en el script.
RG="$(terraform -chdir="$RAIZ" output -raw resource_group)"
PG="$(terraform -chdir="$RAIZ" output -raw postgres_servidor | cut -d. -f1)"
APP="$(terraform -chdir="$RAIZ" output -json nombre_web_app_api | jq -r --arg a "$AMBIENTE" '.[$a]')"
REGLA="seed-temporal-${AMBIENTE}"

CONTRASENA="$(pbpaste)"
if [ "${#CONTRASENA}" -lt 12 ]; then
  echo "Copia primero la contraseña del admin (mínimo 12 caracteres) al portapapeles."
  exit 1
fi

IP="$(curl -s -4 -m 10 https://api.ipify.org)"
[[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "No se pudo obtener tu IP pública"; exit 1; }

cerrar() {
  echo "Cerrando el firewall (${REGLA})..."
  az postgres flexible-server firewall-rule delete -g "$RG" --server-name "$PG" \
    --name "$REGLA" --yes -o none 2>/dev/null || true
  printf '' | pbcopy
  echo "Firewall cerrado y portapapeles limpio."
}
trap cerrar EXIT

echo "Abriendo el firewall de ${PG} solo para ${IP}..."
az postgres flexible-server firewall-rule create -g "$RG" --server-name "$PG" \
  --name "$REGLA" --start-ip-address "$IP" --end-ip-address "$IP" -o none

DATABASE_URL="$(az webapp config appsettings list -g "$RG" -n "$APP" \
  --query "[?name=='DATABASE_URL'].value | [0]" -o tsv)"
[ -n "$DATABASE_URL" ] || { echo "No se encontró DATABASE_URL en ${APP}"; exit 1; }

echo "Ejecutando el seed en ${AMBIENTE} (${APP})..."
(
  cd "$API_REPO"
  DATABASE_URL="$DATABASE_URL" \
    SEED_ADMIN_CORREO="$CORREO" \
    SEED_ADMIN_CONTRASENA="$CONTRASENA" \
    SEED_ADMIN_NOMBRE="Administrador" \
    npx prisma db seed
)

echo "Comprobando el login en https://${APP}.azurewebsites.net ..."
CODIGO="$(jq -n --arg c "$CORREO" --arg p "$CONTRASENA" '{correo:$c, contrasena:$p}' |
  curl -s -o /dev/null -w '%{http_code}' -m 15 -X POST "https://${APP}.azurewebsites.net/login" \
    -H 'Content-Type: application/json' --data-binary @-)"
if [ "$CODIGO" = "200" ] || [ "$CODIGO" = "201" ]; then
  echo "✅ El admin inicia sesión en ${AMBIENTE} (HTTP ${CODIGO})"
else
  echo "⚠️ El login respondió HTTP ${CODIGO}"
  exit 1
fi
