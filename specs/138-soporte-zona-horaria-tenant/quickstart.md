# Guía de validación — Soporte de zonas horarias por tenant

Escenarios ejecutables que demuestran de punta a punta que la spec 138 funciona. **No contiene código de
implementación**: el detalle de cada cambio está en [contracts/](./contracts/), [data-model.md](./data-model.md) y, al
generarse, en `tasks.md`.

Rutas: `BE=/home/leonardo-gomez/Documentos/skeilo/pos-backend` · `FE=/home/leonardo-gomez/Documentos/skeilo/pos-heladeria`.
Base de desarrollo: contenedor Docker `pos` (credenciales en `$BE/.env`). `pos-api` en Docker entra en bucle de reinicio
por diseño de desarrollo (los hosts del `.env` apuntan a `localhost`): usar `uvicorn` nativo o solo las pruebas.

## 0. Prerrequisitos

- Ramas de trabajo creadas **antes** de tocar código, desde `develop`, en `pos-backend` y `pos-heladeria`:
  `fix/138-tenant-timezone-support` (Principio XIV). `pos-specs` se trabaja en `main` (solo documentos).
- Contenedor `pos` arriba (`docker ps`), con `alembic upgrade head` aplicado en desarrollo.
- Nunca correr a la vez la suite completa del backend y la del frontend (la contención de CPU produce falsos fallos).

## Q1 — Pruebas con la zona del sistema forzada (US6, FR-012, SC-008)

```bash
# Backend: ~110 s por corrida, 1905 pruebas en la línea base
cd $BE
env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'             # zona de la máquina
TZ=Asia/Tokyo env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
TZ=UTC        env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
env/bin/python -m app.scripts.test_promotions_rules                                           # CI dedicado de A-57

# Frontend: correr SOLO esta suite (sin la del backend en paralelo)
cd $FE
npx ng test --watch=false                                  # completo; comparar por NOMBRE de prueba contra la línea base
TZ=Asia/Tokyo npx ng test --watch=false
TZ=UTC        npx ng test --watch=false
```

**Esperado**: las tres corridas dan el mismo resultado. En la **línea base** (antes de la spec) el backend daba
1 fallo en Bogotá/UTC (el «segundo rechazo», solo entre las 19:00 y las 24:00 de Bogotá) y 2 fallos distintos en Tokio
(pruebas dependientes de la zona); el frontend, 154/154 en los 9 specs de fechas, pero sin casos de otra zona. Tras la
spec: **0 fallos nuevos en cualquiera de las tres zonas**. La suite completa del frontend arrastra fallos
preexistentes ajenos (7 archivos: `app.spec`, `auth.service.spec`, `menu.service.spec`, `tenant.service.spec`,
`pos-checkout-panel`, `pos-order-panel`, `pos-terminal.store`): compararlos por nombre contra la línea base.

## Q2 — La sesión de la base de datos es UTC aunque el entorno diga otra cosa (US4, FR-004, FR-005, SC-006)

```bash
cd $BE
# El script no escribe nada permanente: usa una tabla TEMP. Probar con zonas "hostiles" en el entorno del cliente:
PGTZ=America/Bogota env/bin/python -m app.scripts.verify_timezone_storage
PGTZ=Asia/Tokyo     env/bin/python -m app.scripts.verify_timezone_storage
env/bin/python -m app.scripts.verify_timezone_storage
```

**Esperado en las tres**: el script imprime primero la zona **cruda** de una conexión sin forzar (informativa: con
`PGTZ=America/Bogota` muestra `America/Bogota` y el defecto original, `17:00 UTC → 12:00`) y después la de la
**conexión de la aplicación**, que debe ser `UTC`; el instante `2026-10-25 17:00 UTC` se guarda como `17:00`; `now()`
coincide con la hora UTC real; todas las zonas de los tenants son válidas (Python y PostgreSQL); salida final `OK`.

Además, la prueba unitaria de `force_utc_session` (conexión simulada) comprueba que se ejecuta `SET TIME ZONE 'UTC'` y
que `autocommit` queda como estaba.

## Q3 — La base de datos rechaza una zona inválida (US5, FR-010, SC-007)

Aplicar la migración (`env/bin/alembic upgrade head`) y probar **sin dejar rastro**:

```bash
docker exec -i pos psql -U "$(grep ^POSTGRES_USER= $BE/.env | cut -d= -f2)" -d "$(grep ^POSTGRES_DB= $BE/.env | cut -d= -f2)" <<'EOF'
\set ON_ERROR_STOP off
BEGIN;
SAVEPOINT a; UPDATE shared.tenants SET timezone = 'Nowhere/Land' WHERE host = 'tenantlocal'; ROLLBACK TO a;   -- ERROR 22023
SAVEPOINT b; UPDATE shared.tenants SET timezone = 'localtime'    WHERE host = 'tenantlocal'; ROLLBACK TO b;   -- ERROR 22023
SAVEPOINT c; UPDATE shared.tenants SET timezone = ''             WHERE host = 'tenantlocal'; ROLLBACK TO c;   -- ERROR 22023
SAVEPOINT d; UPDATE shared.tenants SET timezone = 'America/Mexico_City' WHERE host = 'tenantlocal';          -- OK
SELECT host, timezone FROM shared.tenants WHERE host = 'tenantlocal';                                          -- America/Mexico_City
ROLLBACK;
SELECT host, timezone FROM shared.tenants WHERE host = 'tenantlocal';                                          -- America/Bogota (intacto)
EOF
```

**Esperado**: los tres primeros fallan con `Zona horaria inválida` (SQLSTATE `22023`); el cuarto pasa; al final el tenant
conserva `America/Bogota`. Probar también las siete zonas de la lista curada (todas deben pasar), que el alias heredado `Asia/Calcutta` falla igual (pasa
Python, no PostgreSQL) y el rechazo desde
el script: `python -m app.scripts.set_tenant_timezone --host tenantlocal --timezone Nowhere/Land` ⇒ error, nada
persistido. **Reversa**: `env/bin/alembic downgrade -1` elimina el disparador; repetir la primera sentencia ya no falla.

## Q4 — Contrato de instantes de la API (US1, FR-001/003, SC-005, SC-008)

```bash
cd $BE
env/bin/python -m unittest app.characterization_tests.test_contrato_instantes_api -v
```

**Esperado**: pasa. **Sensibilidad (manual, 1 minuto)**: cambiar temporalmente `UtcDatetime` por `datetime` en un campo de
`CategoryResponse` y repetir ⇒ la prueba **falla nombrando `CategoryResponse.created_at`**; revertir el cambio.

Con la API corriendo (uvicorn nativo) y un token válido: `curl -s … /api/v1/products | jq '.items[0].created_at'` debe
terminar en `+00:00`.

## Q5 — Promociones por zona en los cuatro caminos de cobro (US2, FR-006, SC-003)

Promoción activa 18:00–20:00, instante `2026-10-25 23:30 UTC` (y `22:30 UTC` como control):

| Zona del tenant | Hora local | Debe aplicar |
|---|---|---|
| Bogotá | 18:30 | **sí** |
| Ciudad de México | 17:30 | **no** |
| Madrid | 00:30 del 26/10 | **no** |

```bash
cd $BE
env/bin/python -m unittest app.characterization_tests.test_promotions_tenant_timezone_paths -v
```

Cubre venta directa, cobro de mesa (`close_session`, unificado y dividido), mesas fusionadas (`group_bill`), aprobación
y confirmación en efectivo de un pago QR, y la coincidencia vista previa = menú público = cobro. **Esperado**: 0
aplicaciones indebidas en las tres zonas.

## Q6 — «Hoy» es el día local (US3, FR-007, SC-004)

```bash
env/bin/python -m unittest app.characterization_tests.test_payment_attempt_reject app.characterization_tests.test_business_day_boundaries -v
```

**Esperado**: el «segundo rechazo» deja la marca **a cualquier hora del día de Bogotá** (hoy falla entre las 19:00 y las
24:00; verificar justamente en ese rango), con rechazos a las 20:00 y 21:00; en Madrid entre las 00:00 y las 02:00 «hoy»
es el día local; el día de 25 h, el de 23 h y la medianoche inexistente de Santiago tienen cada uno su prueba. Un turno
de caja que cruza la medianoche local sigue atribuido al día de apertura (sin cambio).

## Q7 — Recorrido manual con un tenant en otra zona (US1, SC-001, SC-002)

1. `cd $BE && env/bin/python -m app.scripts.set_tenant_timezone --host tenantlocal --timezone America/Mexico_City`
   (anota la advertencia que imprime).
2. Abrir el POS de `tenantlocal` en el navegador del MCP con la zona del navegador **emulada a `Asia/Tokyo`**
   (herramienta `emulate` de chrome-devtools) y hacer una venta.
3. Verificar que la **misma hora de Ciudad de México** (no la de Tokio ni la de Bogotá) aparece en: Ventas, Órdenes,
   Caja, Inventario («agotado desde hace»), el ticket impreso (vista previa), la terminal (reloj, fecha, **turno
   Mañana/Tarde/Noche**, hora de cada pedido), la gráfica de ingresos por hora (todos los ejes), las notificaciones, el
   plan y las invitaciones pendientes («Enviada el…»).
4. Abrir el **menú público por QR** de una mesa con el navegador en Tokio: la hora de cada pedido es la de Ciudad de México.
5. **Revertir**: `… --timezone America/Bogota`.

**Esperado**: en ninguna pantalla aparece una hora de Tokio o de Bogotá. (Capturas en el informe de la sesión de
implementación.)

## Q8 — Alta de tenant con zona (US5, FR-010, SC-007)

1. Entrar a `admin.<dominio>` como Super Admin → «Nuevo Tenant». El campo **Zona horaria** aparece **vacío**
   («Selecciona una zona»), con las siete opciones en español, y «Guardar» no avanza sin elegir una.
2. Crear un tenant de prueba con «Ciudad de México» y comprobar `GET /api/v1/super-admin/tenants`: su `timezone` es
   `America/Mexico_City`; en la lista, su «Vence» se muestra en esa zona aunque el navegador esté en otra.
3. Por API sin zona: `POST /api/v1/super-admin/tenants` sin `timezone` ⇒ el tenant nace `America/Bogota`. Con
   `"timezone": "Nowhere/Land"` ⇒ **422** y no se crea nada; con el alias `Asia/Calcutta` también **422** (no 500).
4. Limpiar el tenant de prueba (`DELETE` de `shared.users`/`shared.tenants` y `DROP SCHEMA … CASCADE`, como en las specs previas).

## Q9 — Correo de contraseña cambiada (FR-011, SC-010)

```bash
env/bin/python -m unittest app.characterization_tests.test_correo_contrasena_cambiada \
  app.characterization_tests.test_correo_texto_plano app.characterization_tests.test_plantillas_correo_escape \
  app.characterization_tests.test_correo_zona_horaria -v
```

**Esperado**: los tres archivos protegidos pasan **sin modificarse**; el nuevo prueba Bogotá → «(hora de Colombia)»,
Ciudad de México → «(hora de Ciudad de México)», una zona válida fuera de la lista → «(UTC−3)», usuario sin tenant →
Bogotá; y que ningún texto de un tenant fuera de Colombia contiene «Colombia».

## Q10 — Producción: compuerta previa y despliegue (Supuestos de la spec)

**Paso 0 — compuerta (antes de cualquier despliegue):**

```bash
# En el servidor de producción, contra la base real (solo lectura + tabla TEMP)
docker compose exec api python -m app.scripts.verify_timezone_storage
```

- Debe terminar en `OK`. Si **la sesión no es UTC** o los datos históricos no estaban en UTC ⇒ **pausar solo FR-004/FR-005
  en producción**, informar al solicitante y abrir la spec de corrección de datos (estrategia de migración y rollback).
- Si **algún tenant tiene una zona inválida** ⇒ la migración del disparador **se omite con una advertencia** (el
  backend arranca igual); no endurecer la validación en la base de datos hasta resolverlo (misma vía).
- Señal complementaria sobre los datos: `SELECT now() AT TIME ZONE 'UTC' - max(paid_at) FROM <tenant>.payments;` en un tenant
  de uso diario debe dar minutos u horas **positivas pequeñas**; una diferencia cercana a ±5 h delata una sesión
  histórica no UTC.

**Paso 1 — backend** (`deploy.yml`: pull + `up -d`; el `api-entrypoint.sh` corre `alembic upgrade head`, que crea el
disparador). **Paso 2 — frontend.** El orden no deja ventana con horas desplazadas: [research.md](./research.md) Decisión 16.

**Reversa**: revertir el código de cada repositorio por separado; `alembic downgrade -1` elimina el disparador. No hay
datos que restaurar.

## Q11 — No regresión de Bogotá (FR-013, SC-009)

Con `tenantlocal` en `America/Bogota`, comparar contra las **capturas de `develop` tomadas antes de implementar** (T003): con el
navegador emulado en `Asia/Tokyo` y luego en la zona de Bogotá, el ticket (vista previa), el reloj/fecha/turno de la terminal, la
gráfica por hora, las notificaciones, el plan y el «Vence» de Super Admin muestran los **mismos valores**.

**Esperado**: ninguna diferencia, salvo las dos excepciones registradas: A-147 (día de negocio entre las 19:00 y las 24:00:
«segundo rechazo» y nombre del archivo de inventario) y A-148 («agotado desde hace…» y «Enviada el…» dejan de estar desfasados 5 h).

## Mapa de trazabilidad

| Escenario | Historia | Requisitos | Criterios |
|---|---|---|---|
| Q1 | US6 | FR-012 | SC-008 |
| Q2 | US4 | FR-004, FR-005 | SC-006 |
| Q3, Q8 | US5 | FR-010, FR-016 | SC-007 |
| Q4 | US1, US6 | FR-001, FR-002, FR-003 | SC-005, SC-008 |
| Q5 | US2 | FR-006 | SC-003 |
| Q6 | US3 | FR-007 | SC-004 |
| Q7 | US1 | FR-008, FR-009 | SC-001, SC-002 |
| Q9 | US1 | FR-011 | SC-010 |
| Q10 | — | Supuestos | — |
| Q11 | — | FR-013 | SC-009 |
