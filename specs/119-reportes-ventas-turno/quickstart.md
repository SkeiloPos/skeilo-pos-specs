# Quickstart — Validación de Reportes operativos por turno de caja

**Spec**: [spec.md](./spec.md) · **Contracts**: [contracts/](./contracts/) ·
**Data model**: [data-model.md](./data-model.md)

## Prerrequisitos

- `pos-backend` corriendo nativo con `uvicorn` (no Docker — ver memoria
  `reference_pos_api_docker_vs_nativo`), migraciones al día (`alembic upgrade head`: las tres
  revisiones de la spec 119 — tabla `shift_sales_reports` (A), tablas hijas del desglose (B) e
  índices de `cash_shifts` (C); ver [data-model.md](./data-model.md) §4).
- Un tenant de pruebas con al menos una `CashRegister` ("Caja 1") y un usuario con rol admin y
  otro cajero.
- Cliente HTTP (`curl`/Postman) autenticado con el header de tenant y el Bearer del usuario
  correspondiente a cada paso.

## 1. US1 — Reporte exacto de un turno que cruza la medianoche

1. `POST /cash/shifts/open` con `cash_register_id` de "Caja 1", `opening_amount=50000`, a las
   17:00 (hora del tenant) del día 12.
2. Registrar ventas de mostrador (`POST /sales`) que suman $300.000 antes de las 23:59 del día 12.
3. Registrar ventas que suman $150.000 entre las 00:00 y las 01:50 del día 13.
4. `POST /cash/shifts/{id}/close` a las 02:00 del día 13 (sin pedidos activos).
5. `GET /cash/shifts/{id}/sales-report` → verificar `total_sales="450000.00"`, `order_count`
   correcto, `avg_ticket`, `top_products` y `categories` calculados solo con esas ventas.
6. Repetir la consulta pasando el mismo `shift_id` pero vía `GET /cash/reports/period?period=day`
   filtrando por `cash_register_id="Caja 1"` el día 12 → debe incluir este turno completo (ver
   paso 3 de US2).

**Esperado**: los números no cambian si se repite la consulta más de una vez (snapshot, FR-013).

## 2. US2 — Reporte "del día" libre de contaminación nocturna

1. Con el turno del paso 1 ya cerrado (abierto 12, cerrado 13 a las 02:00), abrir un segundo turno
   de "Caja 1" el día 13 a las 17:00 con algunas ventas.
2. `GET /cash/reports/period?period=day&date=2026-10-13` → debe incluir **solo** el turno abierto
   el 13 a las 17:00, no el que abrió el 12 (aunque tenga ventas registradas entre las 00:00 y las
   02:00 del 13).
3. `GET /cash/reports/period?period=day&date=2026-10-12` → debe incluir el turno completo del
   paso 1 (las 450.000 completas), confirmando que las ventas de madrugada del 13 se atribuyen al
   día de apertura (12), no al día calendario de cada venta.
4. Repetir sin `cash_register_id` con un tenant de dos cajas, ambas con turno abierto el mismo
   día → verificar que el total agrega ambas (FR-012/clarification de agregación sin filtro).

## 3. US3 — Cierre de turno bloqueado mientras existan pedidos activos

1. Abrir un turno. Crear 2 pedidos activos sin cobrar: uno `DINE_IN` (confirmado, sin pagar) y uno
   `TAKEAWAY` o `DELIVERY` (sin cobrar).
2. `GET /cash/active-orders` → debe listar los 2.
3. `POST /cash/shifts/{id}/close` (con conteo válido) → debe responder `409` con
   `active_orders` listando los mismos 2 pedidos; el turno sigue `open`.
4. Cobrar uno de los dos pedidos (flujo normal de cobro de mesa/mostrador) y anular el otro.
5. `GET /cash/active-orders` → debe devolver `[]`.
6. `POST /cash/shifts/{id}/close` otra vez → debe completarse con éxito (`200`), y a partir de
   ahí `GET /cash/shifts/{id}/sales-report` debe devolver el snapshot ya calculado
   (`is_live=false`).
7. Repetir con un turno sin ningún pedido activo desde el inicio → el cierre no debe mostrar
   ningún bloqueo relacionado con pedidos (comportamiento sin cambios respecto a hoy).

### 3b. US3 — Bloqueo de cierre en la interfaz (FR-008)

1. En `pos-heladeria` (navegador), con un turno abierto, dejar 2 pedidos activos sin cobrar (uno de
   mesa y uno para llevar o domicilio).
2. Abrir "Cerrar turno", contar el efectivo y confirmar el arqueo.
3. **Esperado**: el modal de arqueo no se cierra; muestra el aviso ámbar "No se puede cerrar: hay 2
   pedido(s) activo(s)" con una fila por pedido (canal · mesa o cliente · hora) y el enlace
   "Ver pedido →" hacia `/dashboard/orders/<id>`; no aparece ninguna acción de "transferir".
4. Cobrar uno y anular el otro desde las pantallas existentes, volver al arqueo y confirmar de nuevo →
   el cierre se completa y el aviso desaparece.

## 4. US4 — Reporte en tiempo real de un turno en curso

1. Abrir un turno, registrar algunas ventas, dejar un pedido activo sin cobrar.
2. `GET /cash/shifts/{id}/sales-report` → `status="open"`, `is_live=true`, `active_orders_count=1`,
   totales reflejando las ventas ya registradas.
3. Registrar una venta adicional y repetir la consulta → los totales deben reflejar la venta
   nueva sin necesidad de cerrar el turno.
4. Cerrar el turno (sin pedidos activos pendientes) y repetir la consulta → `status="closed"`,
   `is_live=false`, mismos totales que el último cálculo en vivo antes del cierre.

## 5. US5 — Reporte limpio para un turno sin ventas

1. Abrir un turno y cerrarlo de inmediato, sin registrar ninguna orden pagada ni pedidos activos.
2. `GET /cash/shifts/{id}/sales-report` → `total_sales="0.00"`, `order_count=0`,
   `avg_ticket="0.00"`, `top_products=[]`, `categories=[]`, sin error `5xx` ni excepción.

### 5b. US5 — Estado vacío en la interfaz (SC-006)

1. En el panel de inicio del administrador, elegir "Turno específico" y seleccionar el turno del
   paso 1 (abierto y cerrado sin ventas).
2. **Esperado**: ventas totales, órdenes y ticket promedio en `0` (con el formato de moneda del
   sistema), el top de productos y las ventas por categoría como estado vacío con su texto, y ningún
   "NaN", "undefined" ni mensaje de error.

## 6. Inmutabilidad del snapshot (SC-003)

1. Tomar el `shift_id` cerrado del paso 1 (US1) y anotar `total_sales` de su `sales-report`.
2. Anular una de las ventas que participó en ese turno (`POST /sales/{id}/void` o equivalente).
3. `GET /cash/shifts/{id}/sales-report` del mismo turno → debe devolver **exactamente** el mismo
   `total_sales`/`order_count`/`top_products`/`categories` que en el paso 1, sin recalcular contra
   el estado actual (la venta anulada sigue contando como si no se hubiera anulado, a propósito).

## 7. Aislamiento multi-tenant y por caja (SC-004)

1. Repetir el escenario de US1 en dos tenants distintos (o dos cajas del mismo tenant) con montos
   distintos.
2. Verificar que `GET /cash/reports/period?cash_register_id=<Caja A>` nunca incluye montos ni
   `shift_ids` de la Caja B, y que ningún endpoint de este contrato es alcanzable con el token/host
   de otro tenant (`404` o aislamiento por `schema_translate_map`, igual que el resto de `/cash/*`).

## 8. Agregación exacta por período (FR-017, SC-007)

1. Cerrar al menos dos turnos distintos de la misma caja, cada uno con ventas de productos
   solapados (p. ej. ambos venden "Helado 1/2L Chocolate", pero en cantidades distintas) y
   productos exclusivos de cada turno.
2. `GET /cash/reports/period?period=week` → calcular a mano la suma exacta de unidades/ingresos de
   "Helado 1/2L Chocolate" entre los dos turnos y verificar que coincide centavo a centavo con la
   entrada correspondiente de `top_products` del período — nunca una aproximación derivada de
   sumar los top-10 ya recortados de cada turno por separado.

## 9. Verificación en el panel de administración (FR-015)

1. Abrir `admin-dashboard.component.ts` en el navegador con un usuario admin.
2. Confirmar que la tarjeta "Ingresos hoy" fue reemplazada por el reporte por turno con selector
   de período (turno actual, turno específico, día, semana, mes, rango personalizado) y selector
   de caja opcional.
3. Cambiar entre período "turno actual" y "día" sin salir de la pantalla de inicio (SC-005) y
   verificar que los números coinciden con los obtenidos por API en los pasos anteriores.

---

# Ampliación US6 — Rendimiento de reportes de período

Verifica FR-018 a FR-023 y SC-008 a SC-010. Las secciones 1–9 siguen siendo válidas y **no deben
cambiar de resultado**: US6 no modifica la interfaz ni los contratos.

## 10. Verificación de US6

### 10.1 Compuerta automática y regresión de identidad (SC-008, SC-009)

Con el entorno virtual del backend activo, en `pos-backend`:

```bash
python -m unittest \
  app.characterization_tests.test_cash_report_query_budget \
  app.characterization_tests.test_cash_report_batch_identity \
  app.characterization_tests.test_cash_shift_sales_report \
  app.characterization_tests.test_cash_close_active_orders -v
```

**Esperado**: todo en verde. Los dos tests existentes (`test_cash_shift_sales_report.py` y
`test_cash_close_active_orders.py`) **no** se modifican (SC-008): comparar su `sha256sum` con la línea
base registrada en `tasks.md` T039 (válido aunque los archivos sigan sin versionar; `git diff` solo
sirve si ya están commiteados, ver T075). La prueba de presupuesto de consultas confirma que 1 turno y 186 turnos ejecutan el
mismo número de sentencias en las tres composiciones (todos con snapshot / mezcla / todos sin
snapshot), y que `close_shift` hace el mismo número de `INSERT` con 1 y con 80 productos. El ejemplo
numérico del escenario 1 de US6 cuadra al centavo: Cono doble 16 u / $80.000 → Paleta 20 u /
$40.000 → Malteada 4 u / $36.000, ventas $156.000, 10 órdenes, ticket promedio $15.600.

### 10.2 Preparar el tenant desechable con volumen

> Todo lo de 10.2 a 10.8 se hace **solo** en un tenant desechable; se elimina en 10.9.

1. Crear un tenant desechable por el flujo habitual de alta (p. ej. subdominio `vol119`) y anotar su
   esquema (`<ESQUEMA>`) y su host. El alta de tenants usa `create_all` con los modelos, así que el
   tenant **nace ya en la forma final** (tablas hijas e índices de `cash_shifts` incluidos); las
   revisiones B y C se ejercitan sobre él en 10.7 y 10.8 con `alembic downgrade`/`upgrade`.
2. Sembrar el volumen (2.190 turnos, 328.500 ventas, ~985.500 líneas y 1.000.006 pedidos; tarda
   algunos minutos):

   ```bash
   docker exec -i pos psql -U admin -d pos_db -v ON_ERROR_STOP=1 -v schema=<ESQUEMA> \
     < specs/119-reportes-ventas-turno/quickstart-volume.sql
   ```

   Verificar el resumen impreso al final. Todo lo sembrado lleva el prefijo `[119-vol]`. El período
   de medición es **octubre de 2026**, que contiene exactamente 186 turnos.
3. Obtener un token de administrador del tenant desechable y definir `API`, `HOST` y `TOKEN` para
   los `curl` siguientes. El tenant se resuelve por el header **`x-tenant-host`** (no por `Host`):
   `HOST` es el `host` del tenant (p. ej. `vol119`), `API` es `http://localhost:8000/api/v1` y el
   token sale de `POST $API/auth/login` con ese mismo header y el correo/contraseña del admin
   (la contraseña del tenant desechable debe tener entre 8 y 12 caracteres).

### 10.3 Peor caso: 186 turnos sin snapshot (SC-010 ≤ 2 s)

```bash
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{time_total}\n' -H "x-tenant-host: $HOST" -H "Authorization: Bearer $TOKEN" \
    "$API/cash/reports/period?period=month&date=2026-10-15"
done
```

**Esperado**: mediana ≤ **2 s**. Comprobar en la respuesta `shift_ids` con 186 elementos e
`is_live=true` (ningún turno sembrado tiene cabecera de snapshot: es el peor caso, equivalente a
turnos D8). *Referencia medida en el diseño: ≈ 0,15 s en la base y ≈ 0,11 s sobre las tablas reales.*

### 10.4 Con snapshot: 186 turnos congelados (SC-010 ≤ 1 s)

```bash
docker exec -i pos psql -U admin -d pos_db -v ON_ERROR_STOP=1 -v schema=<ESQUEMA> -v only_freeze=1 \
  < specs/119-reportes-ventas-turno/quickstart-volume.sql
```

Repetir los cinco `curl` de 10.3. **Esperado**: mediana ≤ **1 s**, `is_live=false`, y **exactamente los
mismos** `total_sales`, `order_count`, `avg_ticket`, `top_products` y `categories` que en 10.3
(los datos son los mismos; solo cambia de dónde se leen). Repetir `only_freeze=1` una segunda vez
no debe duplicar filas ni fallar.

### 10.5 Pedidos activos con 1.000.000 de pedidos históricos (SC-010 ≤ 200 ms)

```bash
curl -s -o /dev/null -w '%{time_total}\n' -H "x-tenant-host: $HOST" -H "Authorization: Bearer $TOKEN" "$API/cash/active-orders"
```

**Esperado**: ≤ **200 ms** y 6 pedidos en la lista (los activos sembrados). Con un turno abierto,
`GET /cash/shifts/{id}/sales-report` devuelve `active_orders_count = 6` y `POST /cash/shifts/{id}/close`
responde `409` con `active_orders` de 6 elementos (el cuerpo y la forma no cambian: FR-023).

### 10.6 Planes de ejecución: índices en uso (SC-010)

1. Capturar el SQL de las cuatro consultas de un reporte de período (p. ej. activando `echo=True`
   del motor en una sesión local de depuración) y ejecutar cada una con
   `EXPLAIN (ANALYZE, BUFFERS)` en `psql`, tras `SET search_path = <ESQUEMA>`.
2. **Esperado**:
   - **Ningún `Seq Scan`** sobre `sales`, `sale_items` ni `customer_orders`.
   - El conteo y la lista de pedidos activos usan `idx_active_order_per_participant`
     (`Bitmap Index Scan`).
   - `cash_shifts` se recorre por `ix__cash_shifts__opened_at` (sin filtro de caja) o
     `ix__cash_shifts__register_opened_at` (con `cash_register_id`) **una vez aplicada la revisión C**
     (10.7). Si el planificador prefiere un `Seq Scan` porque la tabla es pequeña, repetir con
     `SET enable_seqscan = off` y confirmar que usa el índice — el requisito es que el camino por
     índice exista y se use, no que se prefiera en una tabla de unos miles de filas (research.md D13).
   - Las tablas de snapshot se leen por `cash_shift_id`.
3. Confirmar por **columnas** (no por nombre, que varía por entorno) que existe el índice sobre
   `sales (cash_shift_id)`:

   ```sql
   SELECT indexname FROM pg_indexes
    WHERE schemaname = '<ESQUEMA>' AND tablename = 'sales' AND indexdef LIKE '%(cash_shift_id)%';
   ```

### 10.7 Índices sin bloquear escrituras (FR-021, revisión C)

1. Con el tenant cargado, deshacer solo la revisión C (`alembic downgrade -1`: borra los dos
   índices) y dejar en una terminal un cobro repetido cada segundo (`POST /sales` de mostrador sobre
   un turno abierto del tenant, midiendo `time_total`).
2. En otra terminal: `alembic upgrade head` (vuelve a aplicar la revisión C sobre el volumen).
3. **Esperado**: la migración termina; **ningún cobro falla** ni queda esperando a que ella termine
   (cada uno se completa en tiempos normales); y los dos índices quedan válidos:

   ```sql
   SELECT c.relname, i.indisvalid FROM pg_index i
     JOIN pg_class c ON c.oid = i.indexrelid JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '<ESQUEMA>'
      AND c.relname IN ('ix__cash_shifts__opened_at', 'ix__cash_shifts__register_opened_at');
   ```

   (`indisvalid = t` en ambas filas.)
4. **Reejecución**: `alembic downgrade -1 && alembic upgrade head` termina sin errores.
5. **Reparación de un índice inválido**: marcar uno como inválido
   (`UPDATE pg_index SET indisvalid = false WHERE indexrelid = '<ESQUEMA>.ix__cash_shifts__opened_at'::regclass;`,
   solo en desarrollo, como superusuario), luego `alembic stamp <rev_B>` y `alembic upgrade head`.
   **Esperado**: la migración detecta el índice inválido, lo reconstruye y vuelve a quedar con
   `indisvalid = t`.

### 10.8 Migración B: ida y vuelta sin pérdida (rollback del Principio VIII)

1. Con el tenant en `head` y los turnos congelados (10.4), calcular la huella de las filas:

   ```sql
   SELECT count(*), sum(units), sum(revenue),
          md5(string_agg(cash_shift_id::text || product_variant_id::text || units || revenue::text,
                         ',' ORDER BY cash_shift_id, product_variant_id))
     FROM <ESQUEMA>.shift_sales_report_products;
   ```
   (y la equivalente para `shift_sales_report_categories`, ordenando por `cash_shift_id, category_id`).
2. `alembic downgrade 2009eabd2e82` (deshace C y B: las columnas `JSONB` se reconstruyen desde las
   filas) y comprobar que `shift_sales_reports.products_breakdown` tiene contenido.
3. `alembic upgrade head` (la revisión B vuelve a rellenar las filas desde el `JSONB`).
4. **Esperado**: la huella del paso 1 es **idéntica** — rollback y reaplicación sin pérdida.
5. **Idempotencia frente a la forma final** (tenants creados tras el despliegue, que ya nacen con las
   tablas e índices nuevos): con el tenant en `head`, `alembic stamp 2009eabd2e82` y luego
   `alembic upgrade head`. **Esperado**: sin errores y sin duplicar filas (las revisiones B y C
   reconocen que no hay nada que hacer en ese esquema); repetir la huella del paso 1 para confirmarlo.
6. **Idempotencia de la Rev. A** (tenants que ya nacieron en forma final y nunca pasaron por ella): con
   el tenant en `head`, `alembic stamp 607ff811ddff` (la revisión anterior a la A) y luego
   `alembic upgrade head`. **Esperado**: sin errores (la guarda de la Rev. A omite el esquema porque
   `shift_sales_reports` ya existe; B y C tampoco hacen nada), sin duplicar filas y con la huella del
   paso 1 idéntica.

### 10.9 Limpieza

Eliminar el tenant desechable (flujo habitual de baja o `DROP SCHEMA <ESQUEMA> CASCADE` y su fila en
`shared.tenants`). Confirmar que no queda nada con el prefijo `[119-vol]` en ningún esquema.

### Registro de resultados

| Verificación | Umbral | Medido | ¿OK? |
|---|---|---|---|
| 10.1 Tests (presupuesto de consultas, identidad, existentes sin modificar) | todo en verde | 53 tests OK (12 presupuesto + 21 identidad + 20 existentes); `sha256sum` de los 2 existentes idéntico a T039; suite completa 1573 OK | ✔ |
| 10.3 Reporte de 186 turnos sin snapshot | ≤ 2 s (mediana de 5) | 0,348 s (0,53 / 0,35 / 0,33 / 0,34 / 0,36); `shift_ids`=186, `is_live=true` | ✔ |
| 10.4 Reporte de 186 turnos con snapshot | ≤ 1 s (mediana de 5) | 0,033 s (0,031 / 0,030 / 0,033 / 0,033 / 0,033); `is_live=false` | ✔ |
| 10.4 Mismos valores con y sin snapshot | idénticos | `total_sales`, `order_count`, `avg_ticket`, `top_products`, `categories` y `shift_ids` iguales (27.342 órdenes, $391.995.000); `only_freeze=1` repetido no duplica filas | ✔ |
| 10.5 Pedidos activos con 1.000.000 de históricos | ≤ 200 ms | 5,6 ms (12 / 5,6 / 5,2 / 6,4 / 5,2); 6 pedidos; `active_orders_count=6`; `409` con 6 elementos | ✔ |
| 10.6 `Seq Scan` en `sales` / `sale_items` / `customer_orders` | ninguno | Ninguno en ningún escenario (congelado, sin snapshot, con y sin filtro de caja, conteo y lista de activos) | ✔ |
| 10.6 Índices de `cash_shifts` usados | sí | `ix__cash_shifts__opened_at` (sin caja) e `ix__cash_shifts__register_opened_at` (con caja) sin forzar el planificador; con `enable_seqscan=off` también la cabecera y las tablas de snapshot se leen por índice; `idx_active_order_per_participant` en activos; `sales(cash_shift_id)` = `ix_tenant_sales_cash_shift_id` | ✔ |
| 10.7 Cobros durante la migración de índices | ninguno falla ni espera | 40 `POST /sales` (uno por segundo), todos `201`, máx. 0,068 s; la migración duró 0,81 s; `autocommit_block()` dentro del bucle de tenants funcionó (no hizo falta el respaldo) | ✔ |
| 10.7 Índices válidos / reejecución / reparación | `indisvalid = t`, sin errores | Todos `t` en los 4 esquemas; `downgrade -1 && upgrade head` sin errores; índice marcado inválido + `stamp` de la Rev. B + `upgrade head` → detectado, reconstruido, `t` | ✔ |
| 10.8 Huella antes = después de la ida y vuelta | idéntica | `vol119`: 174.508 productos / 17.520 categorías, md5 idéntico; `heladeria` (datos reales: 6 + 4 filas) idéntico; el `JSONB` se reconstruyó con 2.190 cabeceras | ✔ |
| 10.8 Idempotencia frente a la forma final (pasos 5 y 6: `stamp` en A y en `607ff811ddff`) | sin errores, huella idéntica | Ambos pasos sin errores ni filas duplicadas, huella idéntica (la guarda de la Rev. A omite el esquema) | ✔ |

**Medido el 2026-10-15** en el tenant desechable `vol119` (2.190 turnos, 328.500 ventas, 985.500 líneas y
1.000.006 pedidos; PostgreSQL 16 local). Los tiempos de 10.3–10.5 incluyen la autenticación y la resolución
del tenant (son tiempos de `curl` de extremo a extremo, no solo de la consulta). El tenant se eliminó en 10.9.

### Recorrido manual de US1–US5 (T036) sobre el mismo tenant

| Escenario | Cómo | Resultado |
|---|---|---|
| §1 turno que cruza la medianoche | 4 cobros reales por `POST /sales`; el turno se cerró por la API y luego se movieron `opened_at`/`closed_at`/`sold_at` en la base para simular abrir el 12 a las 17:00 y cerrar el 13 a las 02:00 | `20000.00` / 4 órdenes / ticket `5000.00`, `is_live=false` |
| §2 reporte "del día" | `period=day` el 12 y el 13 | El turno cuenta para el 12 y no para el 13 |
| §3 / §3b bloqueo de cierre | 6 pedidos activos sembrados; cierre desde la interfaz | `409` con 6 pedidos; el modal queda abierto con el aviso ámbar, una fila por pedido y enlace "Ver pedido →"; sin acción de "transferir". Tras anular los 6, el mismo modal cierra el turno ("Cuadre perfecto") |
| §4 turno en curso | Turno abierto con 41 ventas | "Turno en curso · 6 pedido(s) activo(s)", `$ 205.000`, 41 órdenes |
| §5 / §5b turno sin ventas | Abierto y cerrado de inmediato | API `0.00` / 0 / `0.00` con listas vacías; interfaz `$ 0` / `0` / `$ 0` con ambos estados vacíos y sin "NaN" ni "undefined" |
| §6 inmutabilidad | Anular una venta del turno cerrado | Mismo `total_sales`, `order_count`, `top_products` y `categories` |
| §7 aislamiento por caja | `cash_register_id` = Caja 1 / Caja 2 / inexistente | 63 y 62 turnos sin intersección; inexistente → `404` |
| §8 agregación exacta | `period=week` contra SQL sobre las ventas crudas | Top-10 y totales (`$88.740.000`, 6.219 órdenes) idénticos al centavo |
| §9 panel de administración | Selector de período, "Turno actual" y "Día" | Cifras del panel (`$ 12.850.000`, 923, `$ 13.922`) = API (`12850000.00`, 923, `13921.99`) |

Hallazgo corregido durante el recorrido: un turno cerrado sin ventas devolvía `total_sales: "0"` en vez de
`"0.00"` (la comprobación `Decimal(x or 0)` descartaba la escala de `Decimal("0.00")`); corregido en
`aggregate_shifts` y cubierto por `test_turno_cerrado_sin_ventas_conserva_la_escala_del_contrato`.
