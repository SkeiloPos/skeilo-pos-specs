# Modelo de datos — Soporte de zonas horarias por tenant

**Spec**: [spec.md](./spec.md) · **Investigación**: [research.md](./research.md)

Esta spec **no agrega tablas ni columnas, no cambia el tipo de ninguna columna de fecha y no migra datos
históricos** (Supuestos de la spec; Principio VII). El único cambio de esquema es **un disparador de validación sobre
`shared.tenants.timezone`**. El resto son reglas de almacenamiento y de cálculo, y tipos del contrato.

---

## 1. Entidad `Tenant` (`shared.tenants`) — campo `timezone`

| Aspecto | Hoy | Después |
|---|---|---|
| Columna | `timezone VARCHAR(255) NOT NULL DEFAULT 'America/Bogota'` | **Sin cambio** |
| Validación en el ORM | `@validates('timezone')` con `ZoneInfo(value)` (captura solo `ZoneInfoNotFoundError`; acepta `localtime`, `Factory`) | `validate_iana_timezone(value)` común (regla de forma, abajo) |
| Validación en la base de datos | Ninguna | Disparador `BEFORE INSERT OR UPDATE OF timezone` |
| Quién la escribe | Solo `scripts/set_tenant_timezone.py` | Alta de tenant (`tenant_create`) **y** el script |
| Valor por defecto fuera del alta de Super Admin | `America/Bogota` | **Igual** |

### Regla de validez (la misma en Python y en PostgreSQL)

Un valor es válido si **(a)** el motor lo reconoce como zona real y **(b)** tiene forma de región (`Área/Lugar`,
puede llevar más de una barra: `America/Argentina/Buenos_Aires`) o es exactamente `UTC`.

| Valor | Python | PostgreSQL 16 | Resultado |
|---|---|---|---|
| `America/Bogota`, `America/Mexico_City`, `America/Lima`, `America/Santiago`, `America/Argentina/Buenos_Aires`, `Europe/Madrid`, `Asia/Tokyo`, `UTC` | ✅ | ✅ | válido |
| `Nowhere/Land`, `Bogota`, `america/bogota`, `UTC+5`, `PST`, `''`, `' '`, `../etc/passwd`, `None` | ❌ | ❌ | **rechazado** |
| `localtime`, `Factory`, `posixrules` (archivos de la máquina, sin forma de región) | rechazado por la regla de forma | rechazado por la regla de forma | **rechazado** (antes: Python los aceptaba) |
| Alias heredados (`America/Buenos_Aires`, `Asia/Calcutta`) | ✅ | ❌ (Debian 13 los separa en `tzdata-legacy`) | rechazado **solo por la base de datos**: la red de seguridad es algo más estricta que el ORM. Las 7 zonas de la lista curada están en ambos. El alta de tenant traduce ese rechazo a **422**. |

Verificado el 2026-10-25 contra Python 3.14/`tzdata` y PostgreSQL 16.14 (Debian). En producción corre
`postgres:16.10`: el script `verify_timezone_storage.py` repite la comprobación de las siete zonas contra ese motor.

### Disparador (migración nueva sobre `shared`, **no** por esquema de tenant)

```text
shared.tenants_validate_timezone()      -- función PL/pgSQL
  NEW.timezone válido si:
      NEW.timezone = 'UTC'  OR  NEW.timezone LIKE '%/%'
  Y   EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.timezone)
  si no: RAISE EXCEPTION 'Zona horaria inválida: %', NEW.timezone USING ERRCODE = '22023'

TRIGGER trg_tenants_validate_timezone
  BEFORE INSERT OR UPDATE OF timezone ON shared.tenants
  FOR EACH ROW EXECUTE FUNCTION shared.tenants_validate_timezone()
```

- **Compatibilidad con datos existentes**: antes de crearlo, la migración selecciona los tenants cuya zona **no**
  cumple la regla; si hay alguno, **no crea el disparador**: imprime una advertencia con la lista (host y valor) y **termina
  sin error**, porque la migración corre en el arranque del API (`api-entrypoint.sh`) y abortar lo dejaría en bucle de
  reinicio (spec, Supuestos: se pausa solo lo que depende de ello). Nunca corrige datos. Tras corregir la zona con
  `set_tenant_timezone` se reaplica la migración (`alembic downgrade -1 && alembic upgrade head` mientras sea la cabeza; si ya
  hay migraciones posteriores, se ejecuta a mano el SQL del disparador). En desarrollo hay 3 tenants, todos `America/Bogota`.
- **Idempotencia**: `CREATE OR REPLACE FUNCTION` y `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER` (mismo estilo de guardas
  `_has_*` que `2d2c3090473f_add_tenant_timezone.py`).
- **Cabeza de Alembic**: al planificar era `c3d9a1f08b42` (`135_cash_movement_payment_method`); al implementar (2026-10-26) `develop` ya había avanzado y la migración nueva (`af8fd44b3c4e`) cuelga de **`c5815ab62693`** (`138_supplier_items_presentation_factor_nullable`).
- **Rollback**: `downgrade()` ejecuta `DROP TRIGGER IF EXISTS …` y `DROP FUNCTION IF EXISTS …`. No modifica filas.
- **Efecto en el código**: un valor inválido que llegue a la base lanza `psycopg.errors.InvalidParameterValue`
  (SQLAlchemy: `DataError`); los caminos legítimos nunca lo alcanzan porque el ORM y el esquema lo rechazan antes, **salvo** los alias heredados
  (`Asia/Calcutta`), que pasan ambos validadores de Python: `tenant_create` captura ese `DataError` (SQLSTATE `22023`, rama
  nueva antes de su `except Exception` genérico) y responde 422. El `flush()` del `Tenant` ocurre antes de `CreateSchema`, en la
  misma transacción, así que no queda nada creado.
- **Pruebas**: SQLite (suites) no ejecuta el disparador; se valida en PostgreSQL real con
  `BEGIN; … ROLLBACK;` (quickstart Q3) y con `verify_timezone_storage.py`.

---

## 2. Entidad `Instante` — reglas de almacenamiento

Hoy: 81 columnas `DateTime` sin zona (UTC por convención) y 2 con zona (`customer_orders.promotion_evaluated_at`,
`sales.promotion_evaluated_at`). **No cambia el tipo de ninguna.**

| Regla | Detalle |
|---|---|
| **Sesión de base de datos** | Toda conexión de PostgreSQL abierta por `app.core.db.engine` ejecuta `SET TIME ZONE 'UTC'` al conectarse (`force_utc_session`). Cubre API, worker, scheduler, Alembic y scripts. |
| **Valores por defecto de la base** | Las 39 columnas naive con `server_default=now()` guardan UTC porque la sesión es UTC. No se tocan sus definiciones. |
| **Una sola forma de escribir** | Columna sin zona ⇒ `utc_now_naive()`. Columna con zona ⇒ `utc_now()` (aware). Prohibido armar `.replace(tzinfo=None)` a mano, `datetime.utcnow()` y `datetime.now()` sin zona (prueba de guarda). |
| **Hora de pared local (excepción por diseño)** | `promotions.starts_at`, `promotions.ends_at` (y `start_time`, `end_time`) se guardan y devuelven como hora local del tenant, sin offset. No se tocan (FR-002). |
| **Datos históricos** | Intactos. No se recalcula ni se migra nada. La corrección **supone** que producción ya corría en UTC (compuerta 0). |

### Funciones del mecanismo central (`app/core/timezone.py`)

| Función | Estado | Contrato |
|---|---|---|
| `resolve_timezone(tenant)` | existe | `ZoneInfo` del tenant; respaldo `settings.TENANT_TIMEZONE` solo si no hay tenant |
| `UtcDatetime` | existe | tipo de salida con offset UTC explícito; trata un naive como UTC |
| `local_day_bounds_utc(day, tz)` | existe | `[00:00 local, 00:00 local siguiente)` en UTC naive; 23/24/25 h |
| `utc_now()` | existe | `datetime` aware en UTC |
| **`utc_now_naive()`** | **nuevo** | `datetime` UTC sin `tzinfo`, para columnas sin zona |
| **`business_today(tenant)`** | **nuevo aquí** (hoy en `cash/reports.py`) | fecha local del tenant ahora |
| **`validate_iana_timezone(value)`** | **nuevo** | devuelve el valor o lanza `ValueError`; regla de la sección 1 |
| **`ZONAS_CURADAS`** | **nuevo** | las 7 zonas del selector, con su nombre y su etiqueta de correo |
| **`etiqueta_zona_correo(zona, instante)`** | **nuevo** | «Colombia», «Ciudad de México»… o `UTC−3` / `UTC+5:30` |

### Día de negocio (sin cambio de algoritmo)

Ventana `[00:00 local del día, 00:00 local del día siguiente)` del tenant, en UTC. Valores **medidos** el 2026-10-25:

| Zona | Día local | Ventana UTC | Duración |
|---|---|---|---|
| Madrid (fin del horario de verano) | 25/10/2026 | 24/10 22:00Z → 25/10 23:00Z | **25 h** |
| Madrid | 24/10/2026 | 23/10 22:00Z → 24/10 22:00Z | 24 h |
| Madrid (inicio del horario de verano) | 29/03/2026 | 28/03 23:00Z → 29/03 22:00Z | **23 h** |
| Santiago (medianoche inexistente) | 06/09/2026 | 06/09 04:00Z → 07/09 03:00Z | **23 h** |
| Ciudad de México | cualquiera | +6 h todo el año | 24 h |
| Bogotá | 25/10/2026 | 25/10 05:00Z → 26/10 05:00Z | 24 h |
| Tokio | 25/10/2026 | 24/10 15:00Z → 25/10 15:00Z | 24 h |

El «día de negocio» de una operación es `instante.astimezone(zona del tenant).date()`; **nunca** `instante.date()` en UTC.
Una venta del 25/10 19:30 de Bogotá (guardada 26/10 00:30Z) cuenta como 25/10.

---

## 3. Entidad `Zona curada` (nueva, estática)

No es una tabla: es una constante duplicada en backend y frontend con prueba de paridad (Decisión 9).

| IANA | Nombre en el selector | Etiqueta del correo |
|---|---|---|
| `America/Bogota` | Bogotá (Colombia) | Colombia |
| `America/Mexico_City` | Ciudad de México | Ciudad de México |
| `America/Lima` | Lima (Perú) | Lima |
| `America/Santiago` | Santiago (Chile) | Santiago |
| `America/Argentina/Buenos_Aires` | Buenos Aires (Argentina) | Buenos Aires |
| `Europe/Madrid` | Madrid (España) | Madrid |
| `Asia/Tokyo` | Tokio (Japón) | Tokio |

Texto del correo: `dd/mm/aaaa · hh:mm a. m./p. m. (hora de {etiqueta})`. Para una zona válida **fuera** de la lista:
`(UTC−3)`, `(UTC+5:30)` (signo menos tipográfico `−`, minutos solo si no son cero). Para Bogotá el texto es **idéntico**
al actual: `… (hora de Colombia)`.

---

## 4. Entidad `Lista de excepciones` (nueva, estática, en el código de la prueba)

`INSTANTES_SIN_OFFSET_PERMITIDOS = {("PromotionResponse", "starts_at"), ("PromotionResponse", "ends_at")}`

Cada entrada lleva su justificación. Agregar una exige citar la decisión que la autoriza. Ver
[contracts/instantes-api.md](./contracts/instantes-api.md).

---

## 5. Cambios de forma en los DTO

| Esquema (backend) | Cambio | Tipo de cambio |
|---|---|---|
| 16 esquemas de respuesta, 13 definiciones (ver contrato) | `datetime` → `UtcDatetime` en 24 campos | forma de un valor existente (añade offset) |
| `TenantCreateWithUser` | `+ timezone: str \| None = None` (validador IANA) | aditivo, opcional |
| `TenantResponse` | `+ timezone: str` | aditivo |
| `MenuBusinessResponse` | `+ timezone: str` | aditivo |
| `construir_correo_contrasena_cambiada` | `+ zona_horaria: str \| None = None` | aditivo, opcional |

| Modelo (frontend) | Cambio |
|---|---|
| `Tenant` (`super-admin/interfaces/tenant.interface.ts`) | `+ timezone: string` |
| `TenantCreateWithUser` | `+ timezone?: string` (la pantalla siempre lo envía) |
| `ResolvedBusiness` (`diner.service.ts`) | `+ timezone: string` |
| `TenantInfo` | sin cambio (ya trae `timezone`) |

---

## 6. Transiciones de estado

No hay estados nuevos. La única regla de transición que depende del día de negocio es la existente de la spec 132:
**«segundo rechazo del día»** — al registrarse un rechazo de un método no efectivo para una mesa, si ya hay ≥ 2 rechazos
de esa mesa dentro del día de negocio local, se escribe la marca `payment.table_repeat_rejection`. Cambia únicamente
la ventana (día local en vez de día UTC): ver A-147.
