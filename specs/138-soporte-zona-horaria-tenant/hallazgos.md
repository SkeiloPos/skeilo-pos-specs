# Hallazgos verificados — spec 138

**Fecha de verificación**: 2026-10-25, sobre la rama `develop` de `pos-backend` y `pos-heladeria`.
**Para qué sirve**: trazar cada requisito de [`spec.md`](./spec.md) hasta el código que lo origina. **No es parte
de los requisitos**: la planificación (`/speckit-plan`) debe reconfirmarlo antes de diseñar, porque el código cambia
y los números de línea se desplazan.

**Leyenda**: ✅ confirmado leyendo el código · 🔶 confirmado parcialmente · ❔ tomado de la solicitud, sin verificar.

## A. Base de datos — FR-004, FR-005 · Historia 4

| Hecho | Estado | Evidencia |
|---|---|---|
| La sesión de PostgreSQL no se fuerza a UTC | 🔶 | `app/core/db.py` no configura ninguna zona de sesión (sin `timezone`, `options` ni `SET`). El efecto con sesión en Bogotá (17:00 UTC → 12:00) viene de la solicitud, verificado por el solicitante ejecutando el engine. |
| Tres formas de escribir fechas | ✅ | `utc_now()` aware (`app/core/timezone.py:51-55`); `datetime.now(timezone.utc).replace(tzinfo=None)` (p. ej. `checkout.py:1053,1084`, `cart/service.py:94`, `notifications/router.py:88`); `server_default=func.now()` (p. ej. `models/cart.py`, `sale.py`, `cash_shift.py`, `payment.py`). |
| Ejemplos `cash/router.py` (closed_at), `checkout.py` (resolved_at, cash_confirmed_at), `inventory/supplier_items.py` (last_cost_at) | ❔ | De la solicitud. |
| Columnas con y sin zona conviven | ✅ | `DateTime(timezone=True)` en `models/sale.py:91-94` y `models/customer_order.py:102`; `DateTime` naive en `core/models.py:71` y la mayoría del resto. **Fuera de alcance unificarlas** (spec.md, Assumptions). |

## B. Promociones sin tenant — FR-006 · Historia 2

✅ Las **ocho** llamadas a `auto_discount` que no pasan el tenant (y caen en la zona global):

| # | Archivo | Línea |
|---|---|---|
| 1 | `app/api/v1/sales/service.py` | 373 |
| 2 | `app/api/v1/orders/tables_advanced.py` | 161 |
| 3 | `app/api/v1/orders/checkout.py` | 1305 |
| 4 | `app/api/v1/orders/checkout.py` | 1650 |
| 5 | `app/api/v1/orders/checkout.py` | 1802 |
| 6 | `app/api/v1/table_sessions/service.py` | 235 |
| 7 | `app/api/v1/table_sessions/service.py` | 758 |
| 8 | `app/api/v1/table_sessions/service.py` | 868 |

Las llamadas que **sí** pasan el tenant: `checkout.py:466, 527, 562, 784`. El respaldo global es
`settings.TENANT_TIMEZONE` (`core/config.py:20`, valor `America/Bogota`), usado por `promotions/service.py:54-57`,
`core/timezone.py:26`, `core/mail_templates/_campos.py:65` y `core/scheduler.py:234`.

## C. «Hoy» con el día UTC — FR-007 · Historia 3

✅ `app/api/v1/orders/checkout.py:1423`: `local_day_bounds_utc(utc_now().date(), tz)` — pasa la fecha **UTC** como si
fuera la fecha **local**. Entre las 19:00 y las 24:00 de Bogotá usa el día siguiente y el conteo de rechazos
(`OrderPaymentAttempt.status == "rechazado"`) queda en una ventana vacía. Es el único caso de este patrón; `cash/reports.py`
(`business_today`) lo hace bien.

## D. Respuestas con `datetime` plano — FR-001, FR-003 · Historia 1

✅ Campos de instante que hoy salen sin offset (los números de línea son de la verificación):

| Módulo | Campos | Línea(s) |
|---|---|---|
| `products/schemas.py` | `available_changed_at`, `created_at`, `updated_at` | 142, 149, 150 |
| `invitations/schemas.py` | `sent_at` | 48 |
| `cart/schemas.py` | `expires_at`, `created_at`, `cash_confirmed_at` (intentos de pago) | 36, 204, 209 |
| `super_admin/schemas.py` | `plan_vence_en`, `created_at`, `updated_at` | 77-78, 99-103, 186 |
| `categories/schemas.py` | `created_at`, `updated_at` | 84-85 |
| `presentations/schemas.py` | `created_at`, `updated_at` | 31-32 |
| `users/schemas.py` | `created_at`, `updated_at` | 40-41 |
| `unit_measures/schemas.py` | `created_at`, `updated_at` | 30-31 |

**No estaban en la lista de la solicitud** (semillas de la auditoría, FR-015): `table_sessions/schemas.py:27`
(`expires_at`) y `promotions/schemas.py:252` (`closed_by_refactor_at`, un instante, no una hora de pared).

**Excepción por diseño (FR-002)**: `promotions/schemas.py:144-145, 186-187, 246-247` (`starts_at`, `ends_at`) y los campos
`start_time`/`end_time`.

> La búsqueda se hizo con una expresión regular simple y puede haber omitido declaraciones con otra forma
> (`Optional[datetime] = Field(...)` se detectó a mano para `plan_vence_en`). El inventario definitivo lo da la
> verificación automática de FR-003, no esta tabla.

El mecanismo ya existente: `UtcDatetime` en `app/core/timezone.py:36`.

## E. Frontend con la zona del navegador — FR-008, FR-009 · Historia 1

✅ en `pos-heladeria/src/app`:

| Sitio de la solicitud | Evidencia |
|---|---|
| Ticket impreso | `modules/tables/services/receipt.util.ts:170-176` — compone con `date.getHours()/getMinutes()` |
| Reloj, fecha y «Turno Mañana/Tarde/Noche» de la terminal | `modules/tables/components/pos-terminal-header.component.ts:107, 111, 117` |
| Hora de los pedidos de la terminal | `modules/tables/services/pos-terminal.store.ts:921` (`createdAtLabel`) |
| Etiqueta del turno | `modules/dashboard/components/shift-sales-report-card.component.ts:144` |
| Ejes de la gráfica | `modules/dashboard/pages/admin-dashboard.component.ts:538, 543` (y `338`: `new Date().getHours()`) |
| `\| date` en notificaciones | `modules/dashboard/layout/tenant-header.component.ts:173`, `…/header.component.ts:86` |
| `\| date` en plan | `modules/plan/pages/plan-summary-page.component.ts:55` |
| `\| date` en tenants | `modules/super-admin/pages/tenants-page.component.ts:112` — `plan_vence_en \| date: 'mediumDate'` (solo fecha, zona del navegador). `super_admin/schemas.py` no entrega la zona de cada tenant, así que la lista debe incorporarla (aclaración 2026-10-25: cada fila en la zona de su tenant). `plan_vence_en` es un instante (`plan_limits.py:90` lo compara con `utc_now()`), no una fecha de calendario. |
| `\| date` en invitaciones | `modules/users/components/pending-invitations-list.component.ts:43` |
| Nombre de archivo del export de inventario con día UTC | `modules/inventory/pages/inventory-page.component.ts:654` (`new Date().toISOString().slice(0, 10)`) |
| `isPromoActiveNow` | `promotion-pricing.util` (no releído en esta verificación) ❔ |

**No estaban en la lista** (semillas de la auditoría, FR-015): `modules/tables/pages/public-menu.component.ts:1616`
(hora de los pedidos del comensal), `modules/reports/services/reports.service.ts:63, 294` («hoy» con la zona del
navegador en el selector de fecha de reportes) y `modules/promotions/pages/promotions-page.component.ts:139`.

**Zona de respaldo repetida** (`const DEFAULT_TIMEZONE = 'America/Bogota'`) ✅ en cuatro archivos:
`shared/pipes/tenant-date.pipe.ts:6`, `modules/reports/services/reports.service.ts:22`,
`modules/promotions/pages/promotions-page.component.ts:46` y `modules/promotions/services/promotion.service.ts:40`.

**Mecanismo ya existente**: `TenantDatePipe` (`shared/pipes/tenant-date.pipe.ts`) y `RelativeTimePipe`
(`shared/relative-time.pipe.ts`, el «desde hace…», que delega en el anterior).

## F. Zona del tenant y correos — FR-010, FR-011, FR-016 · Historias 3 y 5

| Hecho | Estado | Evidencia |
|---|---|---|
| La zona solo se fija con script | ✅ | `app/scripts/set_tenant_timezone.py`; `super_admin/router.py` solo importa `utc_now` (no maneja zona). El camino `tenant_create` de `core/db.py` y de las fixtures no se leyó a fondo. 🔶 |
| El alta no la pide y nace en Bogotá | 🔶 | Coherente con lo anterior y con A-46 (`server_default='America/Bogota'`). |
| Validación solo en el ORM | ❔ | De la solicitud; A-46 la describe como «validada contra la base IANA en cada escritura» (a nivel de ORM). |
| Correo con «(hora de Colombia)» fijo y zona global | ✅ | `core/mail_templates/_campos.py:53-70` (`formatear_fecha_hora_colombia`, `ZoneInfo(settings.TENANT_TIMEZONE)`). |

**Pruebas que congelan el texto actual** (no se modifican solo para que pase la nueva implementación; con la
decisión de FR-013 el texto para Bogotá **no cambia**, así que no deberían tocarse):
`characterization_tests/test_correo_texto_plano.py:164-165`, `test_correo_contrasena_cambiada.py:73-85` y
`test_plantillas_correo_escape.py:87-109`.

## G. Pruebas — FR-012 · Historia 6

❔ «Solo 4 archivos de pruebas usan una zona distinta de Bogotá». Archivos del backend que mencionan `timezone`
(no necesariamente con otra zona): `test_cash_timezone.py`, `test_plan_expiration.py`, `test_plan_summary.py`,
`test_promotions_router.py`, `plan_fixtures.py`, `test_cart_service.py`, `test_promotions_rules_admin.py`,
`test_auth_session_revocation.py`. La planificación debe contar cuáles usan realmente otra zona.

## Casos de la misma clase revisados (semillas de FR-015)

| Sitio | Veredicto |
|---|---|
| `reports/service.py:44-60` (agrupa por día con doble `AT TIME ZONE`) | ✅ **Correcto**, no requiere cambio. |
| `core/scheduler.py:105, 190` (compara en UTC naive) | ✅ Correcto: compara instantes. |
| `core/scheduler.py:234` | ✅ Usa la zona del tenant con respaldo global. |
| `inventory/router.py:90` — `date.today().isoformat()` en el nombre del archivo | ⚠ Usa la fecha del servidor, igual que el export del frontend (hallazgo E, ya en alcance). Corregirlo cambia el nombre del archivo de un tenant de Bogotá entre las 19:00 y las 24:00 (hoy sale con el día siguiente): se corrige junto con E y se anota en A-149. |
| `promotions/router.py:52` (`X-Server-Time`) | ✅ Instante con zona; sin cambio. |
