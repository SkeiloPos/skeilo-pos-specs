# Data Model: Vigencia de promociones en la hora local del tenant

Esta spec **no introduce ni modifica ningún campo, columna ni migración** — ambas entidades
ya existen con exactamente los campos que la corrección necesita. Lo que cambia es
exclusivamente qué función recibe cuál valor al momento de evaluar vigencia (ver
`research.md`, Decisiones 2 y 3). Este documento formaliza las dos entidades relevantes y la
relación entre ellas para esta corrección puntual.

## Promoción (`Promotion`, `app/models/promotion.py:44-96`)

Campos relevantes para vigencia (sin cambios):

| Campo | Tipo | Significado para vigencia |
|---|---|---|
| `status` | `str` (`draft`/`active`/`paused`/`finished`) | Solo `active` puede estar vigente. |
| `starts_at` | `datetime \| None` | Fecha/hora de inicio, **interpretada en hora local del tenant** (nunca UTC). Obligatoria al crear (`PromotionCreate.starts_at`, FR-012); no editable tras crear. |
| `ends_at` | `datetime \| None` | Fecha/hora de fin, misma interpretación local. |
| `days_of_week` | `str \| None` | CSV de días permitidos (`0`=lunes … `6`=domingo), evaluado sobre el día local, con la atribución de A-57 cuando la ventana cruza medianoche. |
| `start_time` / `end_time` | `time \| None` | Ventana horaria diaria, admite cruce de medianoche (`start_time > end_time`). |

**Invariante que esta spec protege, no introduce**: toda la vigencia de una promoción
(`status`, `starts_at`/`ends_at`, `days_of_week`, `start_time`/`end_time`) se interpreta en
la hora local **del tenant propietario de esa promoción** — nunca en UTC, nunca en la hora
de otro tenant. Antes de esta corrección esa interpretación usaba un único valor global
(`settings.TENANT_TIMEZONE`) en vez de la columna `timezone` del tenant propietario; después
de esta corrección usa esa columna cuando el llamador la tiene resuelta, con el mismo valor
global como único respaldo (tenant no resuelto). Ver `research.md`, Decisión 2.

## Tenant (`Tenant`, `app/core/models.py:86-114`, schema `shared.tenants`)

Campo relevante (ya existe, sin cambios — introducido en spec 030):

| Campo | Tipo | Notas |
|---|---|---|
| `timezone` | `str`, `NOT NULL`, `server_default='America/Bogota'` | Zona horaria IANA del negocio. Validada al escribir (`@validates("timezone")`, rechaza nombres no reconocidos por `ZoneInfo`). Sin pantalla de autoservicio: se fija vía `app/scripts/set_tenant_timezone.py` (fuera del alcance de esta spec). |

`resolve_timezone(tenant: Tenant | None) -> ZoneInfo` (`app/core/timezone.py:20-26`, spec
030) ya es la única función que debe leer esta columna — el motor de promociones la
reutiliza tal cual, sin reimplementar su propia resolución (mismo patrón que
`orders/service.py`/`sales/service.py`).

## Relación para esta corrección

```text
Tenant.timezone ──(resolve_timezone)──► ZoneInfo
                                            │
                                            ▼
                          _tz(tenant) ──► local_now(now, tenant) ──► _valid_now(promo, now, tenant)
                                                                              │
                                                                              ▼
                                                          active_variant_set_rules(db, now, tenant)
                                                                              │
                                                                              ▼
                                                           evaluate_variant_sets(db, lines, now, tenant)
```

`tenant` es **opcional en toda la cadena** (mismo patrón que ya tenía `_tz()`): un llamador
que no lo pase conserva exactamente el comportamiento actual (respaldo global), por lo que
ningún caller existente se rompe mientras se migra uno por uno (Principio VI, incremental).
El objetivo de esta spec es que los seis sitios reales de evaluación (`research.md`,
Decisión 3) terminen pasando el `Tenant` que su propio router/contexto ya tiene resuelto, no
que el parámetro deje de ser opcional en la firma.

## Estados / transiciones

Sin cambios — `PROMOTION_TRANSITIONS` (`app/models/promotion.py`) no se toca; esta spec no
introduce ningún estado nuevo ni cambia cuándo una promoción puede pasar de uno a otro, solo
corrige la zona horaria con la que se evalúa la vigencia de las que ya están `active`.
