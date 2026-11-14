# Dashboard compartido del portal de Azure con las métricas de la plataforma:
# CPU y memoria del App Service Plan (las 4 Web Apps lo comparten) y requests,
# errores 5xx y tiempo de respuesta de la API en Dev y Prod.
# Son métricas de Azure Monitor: no dependen de Application Insights ni del código.
locals {
  # Cada gráfica: posición en una cuadrícula de 2 columnas y las métricas que dibuja.
  # aggregationType del portal: 1 = suma (total), 4 = promedio.
  graficas_dashboard = [
    {
      titulo = "CPU del App Service Plan (%)"
      x      = 0
      y      = 0
      metricas = [{
        id     = azurerm_service_plan.main.id, namespace = "microsoft.web/serverfarms",
        nombre = "CpuPercentage", agregacion = 4, etiqueta = "CPU Percentage"
      }]
    },
    {
      titulo = "Memoria del App Service Plan (%)"
      x      = 6
      y      = 0
      metricas = [{
        id     = azurerm_service_plan.main.id, namespace = "microsoft.web/serverfarms",
        nombre = "MemoryPercentage", agregacion = 4, etiqueta = "Memory Percentage"
      }]
    },
    {
      titulo = "Requests de la API (Dev y Prod)"
      x      = 0
      y      = 4
      metricas = [for amb, app in azurerm_linux_web_app.api : {
        id     = app.id, namespace = "microsoft.web/sites",
        nombre = "Requests", agregacion = 1, etiqueta = "Requests ${upper(amb)}"
      }]
    },
    {
      titulo = "Errores HTTP 5xx de la API (Dev y Prod)"
      x      = 6
      y      = 4
      metricas = [for amb, app in azurerm_linux_web_app.api : {
        id     = app.id, namespace = "microsoft.web/sites",
        nombre = "Http5xx", agregacion = 1, etiqueta = "Http 5xx ${upper(amb)}"
      }]
    },
    {
      titulo = "Tiempo de respuesta de la API (s)"
      x      = 0
      y      = 8
      metricas = [for amb, app in azurerm_linux_web_app.api : {
        id     = app.id, namespace = "microsoft.web/sites",
        nombre = "HttpResponseTime", agregacion = 4, etiqueta = "Response Time ${upper(amb)}"
      }]
    },
  ]
}

resource "azurerm_portal_dashboard" "main" {
  name                = "${local.prefijo}-dashboard"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = merge(var.tags, { "hidden-title" = "Sistema de Reservas · Métricas" })

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = { for i, g in local.graficas_dashboard : tostring(i) => {
          position = { x = g.x, y = g.y, colSpan = 6, rowSpan = 4 }
          metadata = {
            type = "Extension/HubsExtension/PartType/MonitorChartPart"
            inputs = [
              { name = "options", isOptional = true },
              { name = "sharedTimeRange", isOptional = true },
            ]
            settings = {
              content = {
                options = {
                  chart = {
                    title     = g.titulo
                    titleKind = 2
                    metrics = [for m in g.metricas : {
                      resourceMetadata    = { id = m.id }
                      name                = m.nombre
                      aggregationType     = m.agregacion
                      namespace           = m.namespace
                      metricVisualization = { displayName = m.etiqueta }
                    }]
                    visualization = {
                      chartType           = 2 # líneas
                      legendVisualization = { isVisible = true, position = 2, hideSubtitle = false }
                      axisVisualization = {
                        x = { isVisible = true, axisType = 2 }
                        y = { isVisible = true, axisType = 1 }
                      }
                    }
                  }
                }
              }
            }
          }
        } }
      }
    }
    metadata = {
      model = {
        timeRange = {
          type  = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
          value = { relative = { duration = 24, timeUnit = 1 } }
        }
        filterLocale = { value = "es-mx" }
        filters = {
          value = {
            MsPortalFx_TimeRange = {
              model        = { format = "local", granularity = "auto", relative = "24h" }
              displayCache = { name = "Local Time", value = "Past 24 hours" }
            }
          }
        }
      }
    }
  })
}
