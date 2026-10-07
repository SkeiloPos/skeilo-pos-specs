# Fase 1 — Data Model: Carga agregada (bootstrap) del panel de staff

Ver decisiones técnicas en [research.md](./research.md). Esta funcionalidad **no introduce
ninguna entidad persistida ni migración** (spec.md, Key Entities: "No introduce datos nuevos ni
persistentes"; Constitution Check, Principio VIII: N/A). Lo único que este documento describe es
la forma del DTO de composición y cómo se deriva de las entidades ya existentes, documentadas en
sus propias specs.

## `BootstrapResponse` (DTO de composición, calculado por petición — no persistido)

Corresponde a "Arranque del panel (bootstrap)" en `spec.md` → Key Entities: una agrupación
calculada en el momento de la petición de 3 bloques independientes entre sí, sin estado propio.

| Campo | Tipo | Notas |
|---|---|---|
| `tenant` | `TenantInfoResponse \| null` | Idéntico al body de `GET /tenant` (ver [030-correccion-fechas-zona-horaria/contracts/tenant-info-endpoint.md](../030-correccion-fechas-zona-horaria/contracts/tenant-info-endpoint.md)). `null` si no hay tenant resuelto (Super Admin, FR-007) o si solo esta fuente falló (FR-006) |
| `plan` | `PlanSummaryResponse \| null` | Idéntico al body de `GET /plan` (ver [033-planes-suscripcion-tenant/contracts/tenant-plan-enforcement.md](../033-planes-suscripcion-tenant/contracts/tenant-plan-enforcement.md) § `GET /plan`). `null` por la misma razón que `tenant` |
| `notifications` | `NotificationListResponse \| null` | Idéntico al body de `GET /notifications?page=1&size=20` (ver [077-notificaciones-tiempo-real/contracts/notifications-api.md](../077-notificaciones-tiempo-real/contracts/notifications-api.md) § `GET /notifications`). `null` cuando no hay tenant resuelto (research.md Decisión 6) o si solo esta fuente falló (FR-006) |

**Reglas**:
- Los 3 campos son mutuamente independientes: ninguna combinación de `null`/valor en uno condiciona
  a los otros, salvo la única regla explícita de negocio (sin tenant resuelto → los 3 en `null`,
  research.md Decisión 6).
- La respuesta es siempre `200` — no existe ningún código de error propio de este endpoint más allá
  del `401` estándar de autenticación que ya protege cualquier endpoint de la API (no hay un
  tenant/usuario sin autenticar que pueda llegar aquí).
- No hay ordenamiento ni paginación a nivel del `BootstrapResponse` en sí — cada bloque conserva
  la suya si la tiene (`notifications` trae su propio `page`/`size`/`total`, igual que su endpoint
  individual).
- No hay estado ni transición: cada petición a `GET /bootstrap` recalcula los 3 bloques desde cero,
  sin caché propia (Assumptions de spec.md: "no se asume ningún cacheo adicional más allá del que
  ya pudiera existir hoy en las fuentes individuales").

## Entidades reutilizadas sin modificación

Ninguna de estas cambia de forma por esta spec — se listan solo para trazabilidad de dónde vive
cada una:

- **`TenantInfoResponse`** — `app/api/v1/tenant/schemas.py:6-21` (campos: `id`, `name`, `host`,
  `logo_url`, `receipt_message`, `invoice_prefix`, `timezone`).
- **`PlanSummaryResponse`** — `app/api/v1/plan/schemas.py:19-30` (campos: `plan_name`,
  `ciclo_facturacion`, `plan_vence_en`, `vencido`, `resources`, `modules`).
- **`NotificationListResponse`** / **`NotificationResponse`** — `app/api/v1/notifications/schemas.py:9-30`
  (campos del item: `id`, `event_type`, `related_entity_type`, `related_entity_id`, `payload`,
  `created_at`, `attended_at`, `attended_by_user_id`).

## Frontend — estado derivado, sin modelo nuevo

No se agrega ninguna interfaz TypeScript nueva más allá de un `BootstrapResponse` espejo del
schema del backend (`core/bootstrap/bootstrap.model.ts` o equivalente, con los mismos 3 campos
opcionales). Los signals de estado que ya existen (`TenantInfo | null` en `TenantInfoService`,
`PlanSummary | null` en `PlanSummaryService`, la lista de `NotificationItem[]` en
`NotificationCenterService`) no cambian de forma — solo ganan una segunda vía para poblarse
(`hydrate()`, research.md Decisión 7) además de su `load()`/`bootstrap()` existente.
