# Investigación (Fase 0) — Soporte de zonas horarias por tenant

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Fecha de la investigación**: 2026-10-25 (noche, hora de Bogotá)

**Método**: lectura de código en `pos-backend` y `pos-heladeria` (rama `develop` de ambos) y, donde la lectura no
basta, **ejecución real**: contra la base de desarrollo (contenedor Docker `pos`, PostgreSQL 16.14), contra el
esquema OpenAPI de la aplicación y contra las suites de pruebas bajo tres zonas de sistema. Todo lo que dice
«medido» o «verificado» se ejecutó en esta sesión; no se tomó de la solicitud ni de `hallazgos.md`.

No quedó ningún `NEEDS CLARIFICATION` abierto. Lo que depende de producción (que no se puede consultar desde aquí)
queda como **compuerta previa al despliegue** (Decisión 14), tal como prevén los Supuestos de la spec.

---

## R0. Reconfirmación de los hallazgos de la spec

[`hallazgos.md`](./hallazgos.md) pedía reconfirmar todo antes de diseñar. Resultado:

| Hallazgo | Estado tras reconfirmar | Evidencia nueva (2026-10-25) |
|---|---|---|
| **A** — la sesión de PostgreSQL no se fuerza a UTC | ✅ **Reproducido en PostgreSQL real** (era 🔶) | Con la sesión en `America/Bogota`, un `datetime` aware de 17:00 UTC queda guardado como **12:00**, y `now()::timestamp` devuelve la hora de Bogotá (20:00 cuando en UTC eran las 01:00). Con la sesión en Tokio, 17:00 UTC queda como 02:00 del día siguiente. Solo **39 columnas** `DateTime` naive tienen `server_default=now()` (de 81 naive; las 2 con zona son `promotion_evaluated_at`) y dependen de la sesión. No hay ningún `now()` en consultas fuera de los modelos. |
| **A** — tres formas de escribir | ✅ y cuantificado | `utc_now().replace(tzinfo=None)` ×18 sitios, `datetime.now(timezone.utc).replace(tzinfo=None)` ×10 (incluye un helper privado duplicado, `cart/service.py::_now`, y el `default=` de `order_payment_attempt.py:107`), `utc_now()` **aware** asignado a columnas naive ×10 (`cash/router.py:186` `closed_at`; `checkout.py:984,1269,1402,1781` `resolved_at`; `checkout.py:1627` `cash_confirmed_at`; `supplier_items.py:136,147,219,359` `last_cost_at`). Los ejemplos de la solicitud existen y las 4 columnas son naive. |
| **B** — 8 llamadas a `auto_discount` sin tenant | ✅ | Las 8 existen. **Las 8 funciones que las contienen no reciben `tenant`** (`reject_payment_attempt`, que sí lo recibe, no contiene ninguna de las 8 llamadas); hay que enhebrarlo desde el router, incluidas dos reenviadoras (`close_session`, `set_assignments`) (Decisión 4). |
| **C** — «hoy» con el día UTC (`checkout.py:1423`) | ✅ **y ya rompe una prueba hoy** | La suite del backend, corrida a las 20:12 de Bogotá, falla en `test_payment_attempt_reject … test_segundo_rechazo_del_dia_en_la_misma_mesa_escribe_marca_de_revision` (`0 != 1`). Es el defecto real, no un fallo de la prueba: a partir de las 19:00 de Bogotá la ventana del «día» queda vacía. |
| **D** — respuestas con `datetime` plano | ✅ **inventario definitivo: 16 esquemas** (la tabla de `hallazgos.md` omitía 2) | Obtenido del OpenAPI real (Decisión 3). Aparecen además **`PaymentMethodCatalogResponse`** y **`PlanResponse`** (`created_at`/`updated_at`), que `hallazgos.md` no listaba. Detalle en [contracts/instantes-api.md](./contracts/instantes-api.md). |
| **E** — frontend con la zona del navegador | ✅ y ampliado | Todos los sitios de la tabla existen. Nuevos (FR-015): `tenant-info.component.ts:261` (ticket de prueba), `public-menu.component.ts:1616` (confirmado), `reports.service.ts:63`, `admin-dashboard.component.ts:338` (saludo por hora del navegador). El menú público **no entrega la zona del negocio al comensal** (`MenuBusinessResponse` solo trae `name` y `logo_url`): hace falta un campo nuevo (Decisión 11). |
| **F** — la zona solo se fija por script | ✅ (era 🔶) | `tenant_create()` no tiene parámetro de zona; `TenantCreateWithUser` tampoco; el modelo valida con `@validates` solo en el ORM. De las tres plantillas de correo **solo `contrasena_cambiada` muestra una hora** (invitación y restablecimiento no). |
| **G** — «solo 4 archivos de pruebas usan otra zona» | ✅ | Backend: `test_promotions_service`, `test_cart_service`, `test_tenant_timezone`, `test_orders_checkout`. Frontend: solo 2 specs (`tenant-date.pipe.spec`, `cash-session.store.spec`). |
| Producción corre en UTC | ⏸ **No verificable desde aquí** | Se convierte en compuerta previa al despliegue con una verificación ejecutable (Decisión 14). En desarrollo la sesión es `Etc/UTC`. |
| Zonas de los tenants existentes son válidas | ✅ en desarrollo; ⏸ en producción | Los 3 tenants de desarrollo tienen `America/Bogota`. El mismo `verify_timezone_storage` lo comprueba en producción antes de crear el disparador. |

### Hallazgos adicionales de la auditoría (FR-015)

Ninguno cambia lo que ve un tenant de Bogotá más allá de A-147/A-148, así que **se corrigen dentro de esta spec**:

1. **Dos pruebas dependen de la zona de la máquina** (medido corriendo la suite con `TZ=Asia/Tokyo`): `test_auth_session_revocation::test_same_wall_clock_second_as_cutover_is_not_rejected` (llama `.timestamp()` sobre un `datetime` naive en UTC, que Python interpreta como hora local) y `test_table_sessions_router::test_401_por_inactividad_no_lleva_la_cabecera` (usa `datetime.now()` naive en vez de UTC). El código de producción de ambas es correcto (el comentario de `dependencies.py` documenta exactamente esa trampa). Bajo la spec (FR-012) son pruebas defectuosas. Ninguna lleva el prefijo `CONGELA`.
2. **La suite del backend depende de la hora del día**, no solo de la zona: la prueba del «segundo rechazo» falla entre las 19:00 y las 24:00 de Bogotá con cualquier zona de sistema (también con `TZ=UTC`). Se arregla con el cambio de código (Decisión 5), no tocando la prueba.
3. Los instantes del SSE (`events.py`) y de la auditoría ya son aware (`datetime.now(timezone.utc).isoformat()`); el `_jsonable` de `events.py` convertiría un `datetime` naive sin offset, pero **ningún payload actual lleva uno** — sin cambio.
4. No existe en el frontend ninguna compensación manual del offset (`getTimezoneOffset`, `+ 'Z'`, `replace(' ', 'T')`…): al agregar el offset **no hay riesgo de corregir dos veces** (la duda que deja abierta A-148).
5. De los campos que pasan a llevar offset, el frontend **muestra** solo `available_changed_at` (`| relativeTime`), `sent_at` (invitaciones) y `plan_vence_en` (plan, tenants); `cash_confirmed_at`/`expires_at` solo se usan como verdadero/falso.
6. Quedan **correctos y sin cambio** (para no tocarlos por error): `reports/service.py:44-60` (doble `AT TIME ZONE`), `cash/reports.py` (`business_today`, buckets), `scheduler.py` (compara instantes y usa la zona del tenant), `promotions/router.py:52` (`X-Server-Time`), `reports.service.ts::getDateRange` (aritmética de calendario sobre una fecha ya local), `order-date-filter.component.ts`, `promotions-page.component.ts::fmtDate` (fecha con mediodía local fijo), `admin-dashboard.component.ts::loadTrend`.

### Línea base de pruebas (medida, antes de cambiar nada)

| Suite | Zona del sistema | Resultado |
|---|---|---|
| Backend `unittest discover` (1905 pruebas, ~110 s) | Bogotá (20:12) | 1 fallo: el «segundo rechazo» (defecto C) |
| Backend | `TZ=UTC` | 1 fallo: el mismo |
| Backend | `TZ=Asia/Tokyo` | 2 fallos: las dos pruebas dependientes de la zona (punto 1). El «segundo rechazo» pasa solo por coincidencia de la hora. |
| Frontend, 9 specs de fechas (154 pruebas) | Bogotá / Tokio / UTC | 154/154 en las tres: **pasan aunque el código sea incorrecto**, porque casi ninguna ejercita una zona de tenant distinta de la del navegador. |

---

## Decisión 1 — La sesión de PostgreSQL se fuerza a UTC con un evento `connect`, no con `options` (FR-004)

- **Decisión**: en `app/core/db.py`, registrar sobre el `engine` (solo si el dialecto es `postgresql`) un listener
  del evento `connect` que ejecute `SET TIME ZONE 'UTC'` con la conexión DBAPI en `autocommit` temporal. La función
  se llama `force_utc_session` para poder probarla con una conexión simulada.
- **Justificación (medida)**: se probaron las dos alternativas contra la base real con `PGTZ=America/Bogota` y
  `PGTZ=Asia/Tokyo`:
  - `connect_args={"options": "-c timezone=UTC"}` **no funciona**: la sesión sigue en la zona de `PGTZ`
    (`17:00 UTC → 12:00`). El parámetro de arranque que libpq deriva de `PGTZ` gana.
  - El evento `connect` con `SET TIME ZONE 'UTC'` **sí funciona** en todos los casos (con y sin `PGTZ`), sobrevive a
    `rollback()` y al reciclado del pool, y deja `17:00 UTC → 17:00` y `now()` = UTC real.
- **Alternativas descartadas**: `options` en `connect_args` (medido, no funciona); `ALTER DATABASE/ROLE … SET timezone`
  (es infraestructura, también la pisa `PGTZ`, y no viaja con el código); cambiar los 39 `server_default=now()` a
  `timezone('utc', now())` (39 migraciones sobre todos los esquemas de tenant — viola Principios VI/VIII por
  tamaño, y no cubre los `datetime` aware que se escriben desde la aplicación).
- **Cobertura**: un solo `engine` lo usan la API, el worker de Celery, el scheduler, Alembic (`env.py` importa
  `engine`) y los scripts, así que un único listener cubre los cinco.
- **Verificación**: prueba unitaria del listener con conexión simulada (SQLite en las suites no ejecuta el listener) +
  `app/scripts/verify_timezone_storage.py` contra PostgreSQL real (Decisión 14) y el escenario Q2 del quickstart.

## Decisión 2 — Una sola forma de escribir instantes: `utc_now_naive()` + prueba de guarda (FR-005)

- **Decisión**: agregar a `app/core/timezone.py` la función `utc_now_naive()` (UTC sin `tzinfo`) y establecer la
  regla: **columna `DateTime` sin zona ⇒ `utc_now_naive()`; columna `DateTime(timezone=True)` ⇒ `utc_now()`** (hoy
  solo `promotion_evaluated_at`). Sustituir los 28 sitios que arman `….replace(tzinfo=None)` a mano (incluido el helper privado
  `cart/service.py::_now`) y los 10 sitios que asignan un aware a una columna naive.
- **Justificación**: con la sesión ya en UTC (Decisión 1) los 10 aware se guardan bien, pero FR-005 pide **una sola
  forma**; y con una sola forma un cambio futuro de la sesión no vuelve a corromper nada. El `default=` de
  `order_payment_attempt.py:107` (un `lambda` con la forma larga) pasa a usar el mismo helper.
- **Prueba de guarda** (`test_instantes_forma_unica.py`): recorre el árbol `app/` (menos `characterization_tests`,
  `scripts/test_*` y `core/timezone.py`) con `ast` y falla si encuentra `.replace(tzinfo=None)` sobre
  `utc_now()`/`datetime.now(...)`, `datetime.utcnow()` o `datetime.now()` sin zona. Cubre FR-005 y la regresión.
- **Alternativas descartadas**: un `TypeDecorator` o un listener `before_flush` que normalice todo aware a naive
  (magia central en el camino caliente de cada escritura del POS, y oculta el error en vez de impedirlo); dejar los
  10 aware "porque ya funcionan" (incumple FR-005).
- **No se hace**: cambiar el tipo de ninguna columna (Supuestos de la spec).

## Decisión 3 — El contrato del instante se amplía a 16 esquemas y se verifica con el esquema OpenAPI (FR-001, FR-003)

- **Decisión**: reemplazar `datetime` por `UtcDatetime` (ya existe, `app/core/timezone.py:36`) en los campos de
  [contracts/instantes-api.md](./contracts/instantes-api.md). Agregar `test_contrato_instantes_api.py`, que construye
  el esquema OpenAPI de la aplicación, recorre **solo los esquemas alcanzables desde las respuestas** y falla si algún
  campo sale con `format: date-time` fuera de la lista `INSTANTES_SIN_OFFSET_PERMITIDOS`.
- **Justificación (medida)**: `UtcDatetime` usa `PlainSerializer(return_type=str)`, así que en el OpenAPI de salida
  aparece como `{"type": "string"}` **sin** `format`, mientras un `datetime` plano aparece como
  `{"type": "string", "format": "date-time"}`. Esa diferencia es un detector exacto, independiente de cómo esté
  escrita la anotación (`Optional[datetime] = Field(...)`, `datetime | None`, herencia…): por eso supera a la regex de
  `hallazgos.md`, que omitía formas. El primer recorrido real encontró **16 esquemas de respuesta** (13 definiciones: los tres
  esquemas de producto heredan de `ProductResponse`) con **24 campos a corregir** más los 2 de la excepción.
- **Excepción FR-002 (única)**: `PromotionResponse.starts_at` y `PromotionResponse.ends_at` (hora de pared local).
  `start_time`/`end_time` son `time` (`format: time`), no se ven afectados.
- **Cómo se importa la aplicación sin base de datos**: `app/main.py` llama `initialize_database()` al importarse, y
  conecta. La prueba sustituye `app.core.db.initialize_database` por una función vacía **antes** de importar
  `app.main`, y usa las variables de entorno inertes de `fixtures.py`.
- **Limitación conocida (documentada, no resuelta)**: no ve endpoints que devuelvan `dict`/`JSONResponse` sin
  `response_model`. La auditoría manual (R0, puntos 3 y 6) no encontró ninguno con instantes sin offset; el endpoint
  del QR devuelve un `dict` cuyos valores son modelos Pydantic, que sí pasan por `UtcDatetime`.
- **Efecto secundario a vigilar**: `PlainSerializer` sin `when_used` se aplica también a `model_dump()` en modo Python
  (devuelve `str`). Si alguna prueba o servicio compara el `datetime` de un `model_dump()` de estos esquemas, fallará;
  es lo esperado y se corrige en esa prueba (la suite completa lo revela).

## Decisión 4 — El `tenant` se enhebra a las 8 funciones que faltan (más 2 reenviadoras), con un parámetro opcional (FR-006)

- **Decisión**: agregar `tenant: Tenant | None = None` (argumento por nombre, mismo patrón que ya usan
  `reject_payment_attempt` y `evaluate_variant_sets`) a: `sales/service.checkout`, `orders/tables_advanced.group_bill`,
  `orders/checkout.approve_payment_attempt`, `_confirm_cash_portion_of_mixed_attempt`, `confirm_cash_payment_attempt`,
  `table_sessions/service.compute_bill`, `_close_unified`, `_close_split` (y la función que las invoca,
  `close_session`, y `set_assignments`, que devuelve `compute_bill`), y pasarlo a `auto_discount(db, lines, instant, tenant)`. Los routers que ya tienen
  `Depends(get_tenant)` (como `sales/router.py:126`) lo pasan; los demás lo declaran. FastAPI resuelve
  `get_tenant` una vez por petición (ya lo hace `get_db`), así que **no agrega consultas**.
- **Justificación**: es el mismo cambio que hizo la spec 127 en seis sitios; los ocho restantes se quedaron fuera.
  El parámetro es opcional para no romper los llamadores de pruebas ni los scripts; la zona global solo se usa si de
  verdad no hay tenant (FR-006).
- **Nota**: `auto_discount` ya acepta `tenant`; el cambio es solo de propagación, sin tocar `_valid_now` (A-57 intacto). **Excepción de firma**: `session_bill` (el endpoint de `compute_bill`) declara `tenant: Annotated[Tenant, Depends(get_tenant)] = None` porque un test protegido lo invoca directo, sin `tenant`; con `= Depends(get_tenant)` esa llamada recibiría el marcador `Depends` (probado el 2026-10-25 en un script aparte: por HTTP `Annotated` resuelve el tenant real; en llamada directa vale `None`).
- **Verificación**: prueba por cada camino (venta directa, cobro de mesa, mesas fusionadas, aprobación de QR) × 3 zonas
  con la promoción 18:00–20:00 (SC-003), y una prueba de coherencia vista previa = menú público = cobro (US2-4).

## Decisión 5 — «Hoy» es siempre `business_today(tenant)`, ahora en el módulo central (FR-007)

- **Decisión**: mover `business_today(tenant)` de `cash/reports.py` a `app/core/timezone.py` (dejando en
  `cash/reports.py` un alias para no tocar a sus llamadores) y usarlo en `checkout.py:1423`
  (`local_day_bounds_utc(business_today(tenant), tz)`) y en `inventory/router.py:90` (nombre del archivo, que además
  necesita declarar el `tenant`).
- **Justificación**: `core/timezone.py` es el "mecanismo central" de la spec 030; `checkout.py` no debe importar de un
  módulo de reportes de caja. Es una función de una línea que ya existe y ya está probada.
- **Efecto en Bogotá (A-147)**: dos rechazos entre las 19:00 y las 24:00 dejan la marca; el archivo de inventario
  lleva el día local. Es la excepción (a) de FR-013, registrada y pendiente de ratificación.

## Decisión 6 — La zona se elige al crear el tenant; el API la acepta opcional (FR-010)

- **Decisión**: `TenantCreateWithUser` gana `timezone: str | None = None` con validador IANA (422 si es inválida);
  `tenant_create(…, timezone: str | None = None)` la asigna al `Tenant` (el `@validates` actúa) y, si es `None`, se
  conserva el `server_default='America/Bogota'`. La pantalla de alta exige elegir una zona, sin valor preseleccionado.
- **Justificación**: es lo que dice la spec ("por cualquier otro camino el valor por defecto sigue siendo
  `America/Bogota`"). El campo es **aditivo**: ningún cliente actual se rompe.
- **`set_tenant_timezone.py` (FR-016)**: se conserva como único camino para un tenant ya creado; ahora imprime la
  advertencia de que el historial se reinterpreta en la nueva zona, y comparte el validador.

## Decisión 7 — Validación IANA en el modelo **y** en la base de datos, con una regla común de forma (FR-010)

- **Decisión (modelo)**: una función `validate_iana_timezone(value)` en `app/core/timezone.py` — usada por el
  `@validates` de `Tenant`, el esquema de alta y el script — exige que el nombre esté en
  `zoneinfo.available_timezones()` **y** que tenga forma de región (`Área/Lugar`) o sea `UTC`.
- **Decisión (base de datos)**: una migración Alembic nueva (sobre `shared.tenants`, **no** por esquema de tenant)
  crea la función `shared.tenants_validate_timezone()` y un disparador
  `BEFORE INSERT OR UPDATE OF timezone` que rechaza (`ERRCODE 22023`) todo valor que no esté en `pg_timezone_names`
  o no cumpla la misma forma. Antes de crear el disparador la migración **comprueba las zonas existentes** y, si hay una
  inválida, **no crea el disparador**: imprime una advertencia que lista las inválidas y termina sin error (Supuesto de la spec: no
  se endurece si hay una inválida; abortar tumbaría el arranque del API, donde corre `alembic upgrade head`).
- **Justificación (medida)**: un `CHECK` no puede consultar `pg_timezone_names` (no admite subconsultas), así que el
  disparador es la única forma de validar contra la base de zonas del propio motor. La comparación entre ambos
  motores mostró diferencias reales que justifican la regla de forma:
  - Python acepta `localtime` y `Factory` (y `posixrules` como archivo), que son basura de la máquina y harían que
    `ZoneInfo('localtime')` dependa del servidor —el mismo defecto que se corrige—; PostgreSQL 16.14 de Debian los
    lista en `pg_timezone_names`. La regla de forma los rechaza en ambos lados.
  - PostgreSQL de Debian 13 **no** lista alias heredados (`America/Buenos_Aires`, `Asia/Calcutta`, `EST`); Python sí.
    La base de datos es entonces algo más estricta: es una red de seguridad y las 7 zonas de la lista curada están
    en ambos (verificado). Queda documentado en [data-model.md](./data-model.md). El alta de tenant traduce ese rechazo a **422**
    dentro de `tenant_create`, que de otro modo lo convertiría en un 500 genérico.
- **Alternativas descartadas**: `CHECK` con función `IMMUTABLE` que consulte el catálogo (miente sobre la
  inmutabilidad); validar solo en la aplicación (no cumple "incluida la base de datos"); `now() AT TIME ZONE x` dentro
  del disparador (acepta abreviaturas y zonas POSIX como `UTC+5`, que no son IANA).
- **Reversa**: `downgrade()` elimina el disparador y la función; no se altera ningún dato.

## Decisión 8 — El correo usa la zona del tenant y conserva «(hora de Colombia)» para Bogotá (FR-011)

- **Decisión**: `app/core/mail_templates/_campos.py` gana `formatear_fecha_hora(momento, zona)` (con la etiqueta
  según la lista curada o el desfase); `formatear_fecha_hora_colombia(momento)` **se conserva como envoltorio de
  Bogotá** y devuelve el mismo texto que hoy. `construir_correo_contrasena_cambiada` recibe `zona_horaria:
  str | None = None` (`None` ⇒ Bogotá, que cubre al Super Admin). `_dispatch_password_changed_email` la toma de
  `user.tenant.timezone` cuando `user.tenant_id` no es `None`.
- **Justificación**: los tres archivos de pruebas de caracterización (`test_correo_contrasena_cambiada`,
  `test_correo_texto_plano`, `test_plantillas_correo_escape`) llaman a `formatear_fecha_hora_colombia(momento)` y
  esperan el texto exacto; conservar la función y su salida los deja **sin tocar** (Principio III). Solo se agregan
  pruebas para otras zonas.
- **Etiquetas** (aclaración 2026-10-25): lista curada ⇒ nombre en español; zona válida fuera de la lista ⇒ desfase
  `(UTC−3)`, `(UTC+5:30)`; sin tenant ⇒ Bogotá. SC-010: ningún correo de un tenant fuera de Colombia contiene «Colombia».

## Decisión 9 — Lista curada de zonas: 7 entradas, duplicada en backend y frontend con prueba de paridad

- **Decisión**: la lista inicial se cierra en las siete que nombra la spec — Bogotá, Ciudad de México, Lima,
  Santiago, Buenos Aires, Madrid, Tokio — definida en `app/core/timezone.py` (`ZONAS_CURADAS`: IANA, nombre del
  selector, etiqueta del correo) y en `pos-heladeria/src/app/shared/tenant-timezones.ts`. Una prueba en cada lado
  compara con el mismo literal.
- **Justificación**: es el mismo mecanismo que ya usa el proyecto para los subdominios reservados
  (`reserved_hosts.py` ↔ `reserved-slugs.parity.spec.ts` ↔ `test_reserved_hosts.py`, spec 091). Un endpoint que
  entregue la lista evitaría la duplicación, pero agrega un contrato y una llamada solo para siete filas estáticas.
- **Ampliarla** es agregar una entrada en cada lado; no toca la validación. Un tenant con una zona válida fuera de la
  lista funciona igual (solo cambia la etiqueta del correo).

## Decisión 10 — Frontend: un único módulo de presentación, sin dependencias nuevas (FR-008, FR-009)

- **Decisión**: `shared/date-format.util.ts` pasa a ser el único sitio con `Intl` y con la zona de respaldo:
  exporta `FALLBACK_TIMEZONE` (la única `'America/Bogota'` del frontend), `businessToday` (ya existe) y
  `zonedParts(instant, tz)` (año, mes, día, hora, minuto, día de la semana). `TenantInfoService` gana
  `timezone` (`computed`, con el respaldo). `TenantDatePipe.transform(value, format, timezone?)` acepta una zona
  explícita (Super Admin y comensal) y su `DEFAULT_TIMEZONE` privado desaparece, igual que los otros tres.
- **Justificación**: `Intl.DateTimeFormat` con `timeZone` es lo que ya usa el proyecto (`TenantDatePipe`,
  `businessToday`); el uso de `formatDate` con zonas IANA está prohibido por su defecto conocido (memoria de la spec
  121). `date-fns-tz`/`luxon`/`dayjs` no están en `package.json` y `Intl` resuelve todo lo necesario, incluido el
  horario de verano (Principio IX: cero dependencias nuevas).
- **Sitios a corregir** (inventario cerrado, 21): ver [contracts/frontend-fechas.md](./contracts/frontend-fechas.md).
- **Prueba de guarda del frontend**: un spec lee las fuentes con `node:fs` (**probado**: el constructor de pruebas de
  Angular 21 lo permite, se ejecutó una sonda que enumeró más de 100 archivos) y falla ante
  `toLocale(Date|Time)String`, `getHours/getDay/getDate/getMonth/getFullYear`, `toISOString().slice`, `| date` o
  `DatePipe` fuera de una lista de excepciones comentada. Es la contraparte de `test_instantes_forma_unica.py`.

## Decisión 11 — El menú público entrega la zona del negocio al comensal (FR-008)

- **Decisión**: `MenuBusinessResponse` gana `timezone: str` (aditivo). `diner.service.ts` lo copia a
  `ResolvedBusiness.timezone` y `public-menu.component.ts::orderTime` formatea con `TenantDatePipe.transform(…, tz)`.
- **Justificación**: el comensal es anónimo y no puede llamar a `GET /tenant` (lo dice el propio docstring del
  esquema), así que la zona solo puede llegar dentro del payload del menú. Es el único cambio de contrato que no
  es un instante.

## Decisión 12 — Super Admin: la lista de tenants entrega la zona de cada fila (FR-008)

- **Decisión**: `TenantResponse` gana `timezone: str`; `tenants-page.component.ts` muestra el vencimiento con
  `tenantDate` pasando `t.timezone`. Las pantallas del Super Admin sin tenant asociado usan `FALLBACK_TIMEZONE`.
- **Justificación**: aclaración 2026-10-25 (el Super Admin y el negocio ven el mismo día). `plan_vence_en` es un
  instante (`plan_limits.py:90` lo compara con `utc_now()`), no una fecha de calendario.

## Decisión 13 — La réplica visual de la vigencia de promociones usa la zona del tenant (FR-009)

- **Decisión**: `isPromoActiveNow(promo, now, timezone)` obtiene día de la semana, hora y fecha con `zonedParts` en la
  zona del tenant y compara `starts_at` **como hora de pared** (cadena `YYYY-MM-DDTHH:mm:ss` contra la hora de pared
  del tenant), sin pasar por `new Date(promo.starts_at)`, que la leería en la zona del navegador.
- **Justificación**: `starts_at`/`ends_at` son la excepción por diseño (hora de pared local); tratarlos como instantes
  es el error que la spec 127 ya corrigió en otro sitio. Solo alimenta la insignia «vigente / fuera de ventana» de la
  lista de administración: el cobro real lo calcula el backend.
- **Sin cambio**: la réplica no implementa el cruce de medianoche de A-57; no es objeto de esta spec.

## Decisión 14 — Compuerta previa al despliegue y script de verificación (Supuestos de la spec)

- **Decisión**: agregar `app/scripts/verify_timezone_storage.py` (mismo estilo que
  `verify_tracks_inventory_backfill.py`): solo lectura y una tabla `TEMP`. Comprueba, contra la base a la que apunte
  `DATABASE_URL`: (1) zona de sesión efectiva = UTC tras `force_utc_session`; (2) un `datetime` aware de 17:00 UTC
  se guarda como 17:00; (3) `now()` ≈ UTC real; (4) zona de cada tenant válida para Python y para
  `pg_timezone_names`; (5) si existe el disparador. También imprime `pg_settings.TimeZone` con su `source` y
  `pg_db_role_setting`, que dicen **de dónde** viene la zona del servidor.
- **Justificación**: la spec exige verificar en la planificación que producción corre en UTC; desde aquí no se puede,
  así que se entrega la verificación ejecutable y se la fija como paso 0 del despliegue. Si falla (1)/(2) en
  producción, **se pausa solo FR-004/FR-005 en producción** y la corrección de datos va en una spec aparte (Principios
  VII/VIII); si falla (4), no se crea el disparador hasta resolverlo.
- **Señal complementaria sobre los datos**: comparar la columna con `server_default=now()` más reciente de una tabla
  de uso diario contra la hora UTC real; una diferencia cercana a ±5 h delata una sesión histórica no UTC. No prueba,
  pero alerta.

## Decisión 15 — Matriz de pruebas con la zona del sistema forzada (FR-012)

- **Decisión**: (a) las pruebas nuevas de zona parametrizan **tres zonas de tenant** (Bogotá, Ciudad de México,
  Madrid) y puntualmente Santiago y Tokio; (b) el flujo de despliegue del backend (`.github/workflows/deploy.yml`) agrega
  un segundo paso de la suite con `TZ=Asia/Tokyo`; (c) el frontend documenta `TZ=Asia/Tokyo npx ng test` y
  `TZ=UTC` en el quickstart (no tiene CI); (d) se corrigen las dos pruebas defectuosas del backend (R0.1) sustituyendo
  `datetime.now()`/`.timestamp()` naive por UTC explícito.
- **Justificación (medida)**: la línea base muestra que hoy hay exactamente tres pruebas sensibles a zona u hora, y
  que el frontend es insensible a la zona del sistema porque nunca la varía. Con la zona forzada, una prueba que "solo
  pasa en Bogotá" **falla visiblemente**.
- **Casos de borde**, con los valores **medidos** con el mecanismo actual (que ya los resuelve bien):
  Madrid 25/10/2026 = `[24/10 22:00Z, 25/10 23:00Z)` = 25 h; Madrid 29/03/2026 = 23 h; Santiago 06/09/2026 =
  `[06/09 04:00Z, 07/09 03:00Z)` = 23 h con la medianoche inexistente absorbida; Ciudad de México = 24 h todo el año;
  el instante `2026-10-26 00:30Z` es 25/10 19:30 en Bogotá, 25/10 18:30 en Ciudad de México y 26/10 01:30 en Madrid; la
  promoción 18:00–20:00 a las `23:30Z` aplica en Bogotá (18:30) y no en Ciudad de México (17:30) ni en Madrid (00:30).

## Decisión 16 — Orden de despliegue y reversa

- **Orden**: **0** compuerta (Decisión 14) → **1** backend (la migración del disparador corre en el arranque, vía
  `api-entrypoint.sh`) → **2** frontend. **No hay ventana con horas desplazadas** porque el backend es compatible hacia
  atrás: los instantes ahora con offset los lee bien el frontend viejo (el navegador de un cajero en Bogotá los
  muestra en la misma zona que el tenant), y los campos nuevos (`timezone` en alta, lista de tenants y menú) son
  aditivos y el frontend viejo los ignora. Con el orden inverso (frontend nuevo contra backend viejo) solo persiste el
  error de 5 h que ya existe hoy; nunca empeora. Las pestañas abiertas con el paquete viejo siguen funcionando
  (`SwUpdate`, spec 134, las recarga una vez).
- **Reversa**: el código se revierte por repositorio de forma independiente; `alembic downgrade -1` elimina el
  disparador; la sesión UTC no deja estado. **Ningún dato se modifica** (Principio VII), así que revertir no exige
  restaurar nada.

---

## Resumen de riesgos residuales (todos aceptados o con compuerta)

| Riesgo | Tratamiento |
|---|---|
| Producción no corre en UTC / hay una zona inválida | Compuerta 0 (Decisión 14); pausa parcial según la spec |
| El disparador rechaza un alias heredado que Python acepta | Documentado; la lista curada está en ambos; el script de soporte informa el error; el alta de tenant lo devuelve como 422 |
| `model_dump()` de esquemas con `UtcDatetime` devuelve `str` | La suite completa lo detecta; se corrige la prueba afectada |
| La prueba del OpenAPI no ve endpoints sin `response_model` | Auditoría manual hecha (R0.3/R0.6); limitación documentada |
| Excepciones de FR-013 (A-147, A-148) sin ratificación del negocio | Siguen **pendientes**; no bloquean la implementación (decisión del equipo de desarrollo) pero deben ratificarse |
