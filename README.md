# Productividad - ALM | Trailer Logistics

Sistema de control de productividad operacional para Almacenaje de Trailer Logistics.

## Descripcion

Plataforma web que permite cargar datos del WMS, calcular automaticamente la productividad diaria de cada operario, y visualizar los resultados en un dashboard interactivo.

## Archivos

- index.html - Pagina de carga de datos
- dashboard.html - Dashboard de productividad
- operarios.html - Gestion de operarios
- schema.sql - Esquema de base de datos (tablas, vistas, funciones)
- detalle_diario_operario.sql - Tabla y funcion de detalle diario por operario

## Base de datos (Supabase)

### Tablas principales
- `3-operarios` - Maestro de operarios con usuario WMS, cargo, factor ajustado
- `3-operarios_alias` - Mapeo de nombres manuales de minuta a usuario WMS (ej: GVALENZUELA -> GUVALENZUE)
- `3-historial_cajas` - Movimientos LPN de cajas desde WMS (solo registra al recepcionista)
- `3-historial_destino` - Movimientos LPN destino desde WMS (solo registra al gruero)
- `3-productividad_final` - Snapshot materializado de productividad diaria por operario
- `3-productividad_semanal` - Productividad semanal por operario
- `3-config_horarios` - Horas de jornada y efectividad por dia de semana

### Vista principal: `3-v_productividad_diaria`

Calcula la productividad combinando 4 tipos de movimiento:

| Tipo | Fuente | Asignado a | Razon |
|------|--------|-----------|-------|
| **LPN Cajas** | Sistema WMS | Recepcionista | El sistema solo registra al recepcionista |
| **LPN Destino** | Sistema WMS | Gruero | El sistema solo registra al gruero |
| **IN Minutas** | Minuta operacional (flujo IN) | `despachado_por` (gruero) | El gruero no queda en LPN cajas, la minuta lo compensa |
| **OUT Minutas** | Minuta operacional (flujo OUT) | `recep_por` (recepcionista) | El recepcionista no queda en LPN destino, la minuta lo compensa |

**Excepcion cliente EASY en OUT:** Ademas se suma `despachado_por` (gruero) x2, porque EASY divide las OS y no aparecen en LPN destino. **Pallets EASY siempre se multiplican x2.**

Formula: `productividad_hora = total_movimientos / horas_efectivas`

### Resolucion de alias
La minuta operacional es manual, por lo que los nombres pueden variar. La tabla `3-operarios_alias` resuelve variantes (ej: GVALENZUELA, GUSTAVO VALENZUELA, GUSTAVO) al usuario WMS correcto (GUVALENZUE).

---
Desarrollado para Trailer Logistics | 2026
