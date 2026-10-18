# Research: Vigencia de promociones en la hora local del tenant

No quedan `[NEEDS CLARIFICATION]` en `spec.md` (una sesión de `/speckit-clarify`, alcance
acotado a US1+US2, tercer hallazgo — activar sin horario/días — excluido a propósito). Esta
fase investiga, sobre el código real de `pos-backend`/`pos-heladeria`, dónde viven
exactamente los dos defectos que `spec.md` describe y qué mecanismo ya existente en el
proyecto puede reutilizarse para corregirlos sin dependencias nuevas (Principio IX).

## Decisión 1 (FR-001): el defecto de fecha UTC-vs-local vive solo en el frontend, en dos sitios

**Decision**: corregir únicamente `pos-heladeria`, reemplazando `new Date().toISOString()`
(fecha UTC) por `businessToday(tz)` (fecha local del tenant), ya existente en el proyecto,
en los dos puntos donde se calcula "hoy" al guardar una promoción sin fecha de inicio
explícita:
- `src/app/modules/promotions/pages/promotions-page.component.ts:1722`
  (`continueToConfigure()`): `starts_at: new Date().toISOString().slice(0, 10)`.
- `src/app/modules/promotions/services/promotion.service.ts:262` (constructor del payload
  de creación/edición): `starts_at: form.starts_at ?? new Date().toISOString()`.

**Rationale**: `new Date().toISOString()` siempre serializa en UTC; en Bogotá (UTC-5) el
día calendario UTC ya es "mañana" desde las 19:00 hora local — coincide exactamente con el
incidente reportado (promoción guardada después de las 7pm quedando con `starts_at` del día
siguiente). El backend no aporta ningún valor por defecto propio: `PromotionCreate.starts_at`
es obligatoria (`app/api/v1/promotions/schemas.py:141`, FR-012) y se persiste tal cual llega
(`app/api/v1/promotions/service.py:824`) — el defecto es 100% de cómputo en el cliente, así
que no hace falta ningún cambio en `pos-backend` para FR-001.

**Mecanismo a reutilizar (sin dependencia nueva)**: `businessToday(timezone: string): string`
(`src/app/shared/date-format.util.ts:7-9`) ya existe exactamente para esta clase de defecto
(introducida en spec 030, FR-004, para el mismo problema en reportes) y ya devuelve
`YYYY-MM-DD` en formato `en-CA`, listo para asignar directo a `starts_at`. La zona horaria
del tenant ya está disponible en el cliente sin petición adicional vía
`TenantInfoService.info()?.timezone` (`src/app/core/tenant/tenant-info.service.ts:19`,
cargado por `GET /tenant`), con el mismo patrón de respaldo (`?? 'America/Bogota'`) ya usado
en `reports.service.ts:293-296`. `grep` confirma que `package.json` no tiene
`date-fns-tz`/`luxon`/`moment`/`dayjs`: `Intl.DateTimeFormat` con `timeZone` es el enfoque ya
establecido en el proyecto — una dependencia nueva no estaría justificada (Principio IX).

**Nota de consistencia (no bloqueante para esta spec)**: `tenant-date.pipe.ts:6` duplica su
propia constante local `DEFAULT_TIMEZONE = 'America/Bogota'` en vez de reutilizar la de
`reports.service.ts:22` — preexistente, fuera del alcance de esta corrección (Principio V:
no se arregla de paso una duplicación no relacionada con el defecto reportado).

**Alternatives considered**: calcular la fecha local a mano con `getFullYear()`/
`getMonth()`/`getDate()` sobre un `Date` ya desplazado por offset — rechazado: es
exactamente el patrón fuente de este tipo de bug (offsets manuales), y `businessToday()` ya
resuelve el caso general (incluye DST si alguna vez aplicara) con `Intl.DateTimeFormat`.

## Decisión 2 (FR-002): el motor de vigencia nunca recibe el `Tenant`, cae siempre al valor global

**Decision**: corregir `pos-backend`, extendiendo con un parámetro `tenant` **opcional**
(mismo patrón que ya tiene `_tz()`) las cuatro funciones del motor de vigencia en
`app/api/v1/promotions/service.py`, y pasando el `Tenant` ya resuelto por cada router en
los seis puntos de llamada reales:

```python
# Ya existe, sin tocar — el único punto que falta es que alguien le pase tenant:
def _tz(tenant: Tenant | None = None) -> ZoneInfo:
    if tenant is not None:
        return resolve_timezone(tenant)
    return ZoneInfo(settings.TENANT_TIMEZONE)
```

Añadir `tenant: Tenant | None = None` y reenviarlo hacia abajo en:
- `local_now(now, tenant=None)` → `_tz(tenant)`
- `_valid_now(promo, now, tenant=None)` → `local_now(now, tenant)`
- `active_variant_set_rules(db, now, tenant=None)` → `local_now`/`_valid_now` con `tenant`
- `evaluate_variant_sets(db, promo_lines, now, tenant=None)` → `active_variant_set_rules`
  (indirectamente, vía `promo_lines`/el llamador ya resuelve las reglas aparte en algunos
  casos — ver Decisión 3 para el detalle exacto por sitio de llamada)

**Rationale**: `_tz(tenant: Tenant | None = None)` **ya soporta un tenant real** desde que
se escribió (cita explícita en su docstring: "Si el caller ya resolvió el tenant... usa la
suya") — el defecto no es de diseño, es que ningún llamador real se lo pasa nunca (`grep`
confirma cero sitios con `tenant=` en las cuatro funciones). Hacerlo opcional con el mismo
respaldo global que ya existe (`ZoneInfo(settings.TENANT_TIMEZONE)`) es el cambio mínimo que
exige el Principio VI (incremental): ningún llamador no migrado se rompe, y cubre además el
"valor por defecto razonable" que `spec.md` (Edge Cases) exige como respaldo, no como
comportamiento normal, para un tenant sin resolver.

**Alternatives considered**: resolver el tenant *dentro* del motor a partir de la `Session`
de SQLAlchemy (p. ej. leyendo el schema activo y volviendo a consultar `shared.tenants`) —
rechazada: reintroduce una consulta y un acoplamiento que el proyecto ya evitó con el patrón
establecido (`resolve_timezone(tenant)` recibiendo el objeto ya resuelto, usado por
`orders/service.py:556` y `sales/service.py:415`); hacerlo distinto aquí sería la clase de
inconsistencia que el Principio V busca evitar.

## Decisión 3: los seis sitios de evaluación ya comparten el mismo motor — "falta pasar tenant", no "falta unificar"

**Decision**: en los tres módulos que `spec.md` (FR-003) exige que concuerden, el `Tenant`
ya está resuelto en el `router` o en el contexto de sesión en **todos** los casos — ninguno
exige una consulta nueva, solo reenviarlo un nivel más abajo:

| Módulo | Endpoint / función | `Tenant` ya disponible como | Falta pasar a |
|---|---|---|---|
| Menú público | `GET /menu` (`public_menu`, `menu/router.py:275`) | no está en la firma hoy — se agrega `tenant: Tenant = Depends(get_tenant)` (mismo caché de dependencia que ya usa `get_db`, sin consulta extra) | `_build_menu(db, tenant)` → `active_variant_set_rules(db, now, tenant)` |
| Menú público | `GET /menu/promotions` (`public_menu_promotions`, `:281`) | ídem, se agrega `tenant: Tenant = Depends(get_tenant)` | `_build_menu_promotions(db, now, tenant)` |
| Menú público (QR firmado) | `GET /menu/qr-token/{token}` (`menu_by_signed_qr`, `:292`) | `ctx.tenant` (`open_qr_context`, ya en el contexto) | `_build_menu(ctx.db, ctx.tenant)` / `_build_menu_promotions(ctx.db, now, ctx.tenant)` |
| Carrito | `serialize_cart` (`cart/service.py:305`, dos llamadores: `get_cart`/`add_item`/etc.) | `ctx.tenant` (`SessionContext`, `app/core/qr_context.py:71`, ya inyectado por `get_session_context`) | se agrega parámetro `tenant` a `serialize_cart` y se reenvía a `evaluate_variant_sets` |
| Carrito | `submit_cart` (`cart/service.py:637`, usa `evaluate_variant_sets` en `:792`) | ídem, `ctx.tenant` ya disponible en `cart/router.py` | mismo cambio de firma |
| Cobro de pedidos/mesas | `auto_discount`/`refresh_order_item_discounts`/`compute_checkout_preview`/`compute_draft_preview`/`pay_order`/`checkout_and_send` (`orders/checkout.py`) | `tenant: Tenant = Depends(get_tenant)` **ya está en la firma de casi todos los endpoints de `orders/router.py`** (17 ocurrencias) | se agrega parámetro `tenant` a cada función de servicio y se reenvía desde el router, que ya lo tiene |

**Rationale**: esto confirma que FR-003 (los tres puntos deben concordar) **ya se cumple
hoy estructuralmente** — los seis sitios llaman a la misma `evaluate_variant_sets`/
`active_variant_set_rules`, nunca a lógica duplicada. El defecto de FR-002 (zona horaria
global) afecta a los seis por igual, así que corregirlo una sola vez en el motor compartido
los corrige a los seis a la vez — no hace falta ninguna unificación adicional, solo
enhebrar el parámetro ya resuelto.

**Alternatives considered**: ninguna — es la constatación directa de cómo ya está
construido el motor, no una decisión de diseño nueva.

## Decisión 4 (FR-004): protección de la ventana de medianoche/A-57 — qué no se debe tocar

**Decision**: `_in_time_window()` y el cuerpo de `_valid_now()` (atribución de día al
cruzar medianoche, A-57, spec 040) **no cambian de lógica**, solo ganan el parámetro
`tenant` adicional descrito en la Decisión 2. La protección de regresión es
`app/scripts/test_promotions_rules.py` (script de CI, no pytest, ejecutado con
`python -m app.scripts.test_promotions_rules`), Sección 1 (líneas 96-126): casos como
`"martes 01:00 local: sigue siendo el lunes de inicio, vigente"` (:121) y los de
`_in_time_window` (:111-113) asumen hoy que, sin pasar `tenant`, el motor cae a
`ZoneInfo(settings.TENANT_TIMEZONE)` = `America/Bogota` — deben seguir pasando exactamente
igual después de esta corrección, porque siguen sin pasar `tenant` (ejercitan el respaldo
global a propósito). Cobertura pytest adicional sobre el mismo motor:
`test_promotions_rules_admin.py` (`test_ca4_ventana_que_cruza_medianoche_aceptada_al_guardar`,
`:292`) y `test_promotions_service.py` (`evaluate_variant_sets`, pricing/agrupación).

**Rationale**: es la aplicación directa de FR-004 y del Principio III — nada en el cruce de
medianoche se toca; el único cambio de comportamiento observable debe ser "ahora usa la zona
del tenant cuando se le pasa uno", nunca "cambió cómo se calcula la ventana en sí".

**Alternatives considered**: ninguna.

## Decisión 5: alcance final — qué NO entra en esta spec

**Decision**: no se corrige (a propósito, ya excluido en `/speckit-clarify`) la posibilidad
de activar una promoción sin horario/días configurado (corriendo 24/7 sin aviso) — problema
de integridad de datos/UX distinto, candidato a spec separada. No se agrega ninguna pantalla
de autoservicio para que el tenant edite su zona horaria (ya existe, vía
`app/scripts/set_tenant_timezone.py`, fuera del alcance). No se migra ni recalcula ninguna
promoción ya guardada con `starts_at` desplazado — se corrige manualmente volviendo a
guardarla (Assumptions de `spec.md`).

**Rationale**: aplicación directa de las Clarifications y Assumptions ya registradas en
`spec.md` — no hay nada nuevo que decidir aquí, solo confirmarlo antes de pasar a Phase 1.

**Alternatives considered**: ninguna.
