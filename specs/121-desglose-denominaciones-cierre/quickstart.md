# Quickstart — Validación del desglose por denominación en el cierre de caja

**Spec**: [spec.md](./spec.md) · **Contracts**: [contracts/](./contracts/) ·
**Data model**: [data-model.md](./data-model.md) · **Research**: [research.md](./research.md)

Guía de validación de extremo a extremo. Cada escenario cita las historias de usuario (US) y los
requisitos (FR/SC) que demuestra. No contiene código de implementación.

## Prerrequisitos

- Ramas `feat/121-denomination-breakdown` creadas desde `develop` en `pos-backend` y `pos-heladeria`
  **antes** de tocar código (Principio XIV).
- Decisiones **A-130 a A-134** (D-1 a D-6) registradas en
  `specs/000-reconocimiento/registro-de-anomalias.md` **antes** de implementar (Principio II).
- PostgreSQL de desarrollo: contenedor `pos` (`docker exec -i pos psql -U admin -d pos_db`).
  `pos-api` corre **nativo** con `uvicorn`, no en Docker (memoria `reference_pos_api_docker_vs_nativo`).
- Un tenant de pruebas con una caja, un usuario admin y otro cajero. Para los pasos con `curl`:
  `$HOST` (cabecera `x-tenant-host`), `$TOKEN_ADMIN`, `$TOKEN_CAJERO`.
- Backend: `cd pos-backend && env/bin/python …` (SQLite 3.46 / SQLAlchemy 2.0.50 / Alembic 1.18.4).

## 0. Línea base (antes de cambiar nada)

1. Backend: `env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` →
   anotar el recuento (referencia: 1574 en la spec 119). Ejecutar **sola**, sin la suite del frontend.
2. Frontend: `git stash push -u -m baseline && npm test && git stash pop` en `pos-heladeria` →
   anotar los fallos preexistentes (7 archivos conocidos; memoria
   `reference_pos_suite_frontend_fallos_preexistentes`). **Nunca** correr ambas suites a la vez.
3. Fotografía de los montos de los turnos cerrados (para SC-004), por esquema:

   ```sql
   SELECT md5(string_agg(id::text || coalesce(counted_amount::text,'NULL')
                         || coalesce(close_note,'') || status, '|' ORDER BY id)),
          count(*)
   FROM heladeria.cash_shifts;
   ```

   (El `coalesce` evita que un turno histórico cerrado sin conteo, con `counted_amount` nulo, quede
   fuera de la huella. Dev, 2026-10-15: 12 turnos, huella `a201b52b0bcb0acfed4f816a07951ee4`.)

## 1. Compuerta previa a migrar (FR-028) y respaldo

1. `docker exec -i pos psql -U admin -d pos_db < specs/121-desglose-denominaciones-cierre/quickstart-preflight.sql`
   → **`fuera_de_catalogo` debe ser 0 en todos los esquemas.** Si no lo es, **detenerse** y resolverlo
   con el negocio (FR-028); la migración también abortaría por sí misma.
   Medido en desarrollo (2026-10-15): `heladeria` 35 filas / 0 en cero / 0 fuera de catálogo;
   `skeilo` y `tenantlocal` vacíos.
2. Respaldo de la tabla de desglose por esquema (necesario para restaurar las filas con cantidad
   `0` que se descartan; Principio VIII):
   `docker exec pos pg_dump -U admin -d pos_db --table='<esquema>.cash_count_denominations' > backup_<esquema>.sql`.

## 2. Migración: subir, comprobar, bajar y volver a subir (R3, SC-004)

1. `env/bin/python -m alembic upgrade head` (la revisión nueva cuelga de `cd3e314a79b8`).
2. Por cada esquema con datos, comprobar:
   - `SELECT count(*) FROM <esquema>.denomination_catalog` = **11** (6 `billete`, 5 `moneda`).
   - `cash_count_denominations.kind` es `NOT NULL` y ninguna fila tiene `quantity = 0`.
   - Cada fila tiene el `kind` que le corresponde por su valor (≥ 2000 → `billete`).
   - `cash_shifts.closed_by_user_id` / `closed_by_user_name` existen y están en `NULL`.
   - El `md5` del paso 0.3 es **idéntico** (0 diferencias en `counted_amount`, `close_note`, estado).
3. `env/bin/python -m alembic downgrade -1` → ya no existen `denomination_catalog`, `kind` ni
   `closed_by_*`; `quantity >= 0` restaurado; **las filas conservadas siguen con su valor y cantidad**.
4. `env/bin/python -m alembic upgrade head` otra vez → mismo resultado que el punto 2 (reversible y
   reejecutable).
5. **Compuerta que aborta**: en una transacción `BEGIN … ROLLBACK` sobre `tenantlocal`, insertar una
   fila con `denomination = 3000` y ejecutar el `INSERT … SELECT` de la compuerta → debe fallar con
   el mensaje que nombra esquema y valor (nada se descarta en silencio). Terminar con `ROLLBACK`.

## 3. API — cierre con desglose (US1, US2, US6)

Con un turno abierto cuyo efectivo esperado sea **$115.000**:

| # | Petición `POST /cash/shifts/{id}/close` | Esperado |
|---|------------------------------------------|----------|
| 1 | `100000×1, 10000×1, 5000×1` | `200`; `counted_amount="115000.00"`; **3** filas guardadas; diferencia `0`; `closed_by_user_name` = quien llamó (US1-1, SC-001) |
| 2 | (turno nuevo) `100000×1, 10000×1` + `close_note` | `200`; contado `110000.00`; diferencia `-5000.00` (US1-2) |
| 3 | (turno nuevo) igual que 2 **sin** `close_note` | `422` «El arqueo no cuadra…»; turno `open`; 0 filas (US1-3) |
| 4 | (turno nuevo) `100000×1, 50000×0, 10000×1, 5000×1` | `200`; **3** filas (la de `50000` no se guarda) (US1-4, FR-015) |
| 5 | (turno nuevo) `{"denominations": [], "close_note": "Caja vacía"}` | `200`; contado `0.00`; 0 filas (US1-5, D-2) |
| 6 | `{"counted_amount": 95000, "denominations": […]}` | `422` con «Recarga la página…»; turno `open`; 0 filas (US1-6, US2-4, D-1) |
| 7 | línea con `denomination: 3000` | `422` «La denominación $3.000 no está registrada…»; 0 filas (US2-1) |
| 8 | `quantity: -1`, y `quantity: 2.5` | `422` (Pydantic) en ambos (US2-2) |
| 9 | `10000×1` y `10000.00×2` en la misma petición | `422` «…repetida…» (US2-3, Edge case) |
| 10 | 9 líneas válidas + 1 inválida | `422`; **ninguna** de las 9 se guarda (US2-5, FR-007) |
| 11 | `100000×1000000000` | `422` «excede el monto máximo»; **no** `500` (Edge case) |
| 12 | Pedido activo sin cobrar + cierre válido | `409` con `active_orders` (spec 119 intacta) (US2-6) |
| 13 | Reenviar el cierre del caso 1 | `409`; desglose, contado y diferencia **idénticos** (US6-1, FR-018, SC-006) |

Tras cada `422`/`409`, comprobar en SQL que el turno sigue `open` (o intacto) y que
`cash_count_denominations` no ganó filas.

## 4. API — catálogo y reporte (US3, US4, US5)

1. `GET /cash/denominations` → 11 elementos, de mayor a menor, 6 `billete` y 5 `moneda` (US3-1/5).
   Con un MESERO → `403`.
2. `GET /cash/shifts/{id}/report` del caso 3.1 → `denominations` con 3 elementos que traen `kind`,
   `quantity` y `subtotal`; **la suma de `subtotal` = `shift.counted_amount`** (FR-021, US4-1).
3. Reporte del caso 3.5 → `denominations: []` y `counted_amount="0.00"` (US4-4).
4. Cerrar con el usuario «Luis» un turno abierto por «Ana» → `closed_by_user_name="Luis"` y
   `user_name="Ana"` (US4-5). Renombrar a Luis en `shared.users` y reconsultar → el reporte
   **sigue** diciendo «Luis» (US4-6).
5. Reporte de un turno histórico sin filas → `denominations: []`, `closed_by_*: null`, `200` (US5-1/4).
   Reporte de uno con filas → todas con `kind` (US5-2).

## 5. Concurrencia (FR-019, SC-006) — solo verificable en PostgreSQL

La suite usa SQLite, que ignora `FOR UPDATE`. Con un turno abierto y desglose válido, lanzar **dos
cierres en paralelo** (dos `curl … &` seguidos de `wait`, o dos hilos con `httpx`), y repetirlo
~20 veces con turnos nuevos:

- Siempre exactamente **un** `200` y **un** `409`; nunca un `500`.
- `SELECT count(*) FROM cash_count_denominations WHERE cash_shift_id = …` = número de líneas de la
  petición (sin duplicados).

## 6. Tenant nuevo recibe el catálogo (R2, FR-012)

`tenant_create()` exige PostgreSQL real; usar la receta de tenant desechable de la memoria
`reference_pos_dev_db_psql_tenantlocal` (llamar `tenant_create(...)` desde Python con contraseña
válida y correo sin `.test`) y comprobar:

- `SELECT count(*) FROM <esquema_nuevo>.denomination_catalog` = **11** sin ninguna acción manual.
- `GET /cash/denominations` con ese tenant devuelve el catálogo por defecto.

Limpieza: `DELETE` de `shared.users`/`shared.tenants` y `DROP SCHEMA <esquema> CASCADE`.

## 7. Pantalla — modal de arqueo (US3)

`ng serve` en `pos-heladeria`, sesión de cajero con turno abierto:

1. Abrir «Arqueo de caja» → 11 filas, de mayor a menor, cada una con su tipo (US3-1). Total y
   diferencia rotulados «(estimado)»; cambian al teclear (US3-2).
2. Con todas las cantidades en 0 el botón de confirmar está **deshabilitado**; se habilita al
   ingresar una cantidad > 0 (US3-7).
3. El campo de **observación está siempre visible** (opcional si cuadra, obligatorio si no) (FR-025).
4. En DevTools → Network, bloquear `GET …/cash/denominations` (o detener `pos-api`) y reabrir el
   modal → mensaje de error + **«Reintentar»**, confirmar deshabilitado, **0** peticiones de cierre
   (US3-6). Desbloquear y pulsar «Reintentar» → el modal carga las filas.
5. Confirmar con un conteo válido → en DevTools la petición `…/close` lleva solo `denominations` y
   `close_note`, **sin** `counted_amount`; se muestra el reporte con los valores del servidor (US3-3).
6. Provocar el `422` de observación (US3-8): con el modal abierto y la estimación en $0, registrar
   una venta en efectivo desde otro terminal y confirmar sin observación → el modal **sigue abierto**,
   conserva las cantidades, muestra el mensaje del servidor y deja escribir la observación.
7. Provocar el `422` de denominación (US3-4): en Postgres, `DELETE` de una denominación del catálogo
   con el modal abierto y confirmar usándola → mensaje que nombra la denominación; el modal sigue
   abierto. Restituir la fila después.

## 8. Pantalla — reporte, histórico e impresión (US4, US5, US6)

1. Tras cerrar (caso 3.1): sección **«Desglose del conteo»** con las 3 filas, «Contado por: {usuario}»
   y fila «Total» = **$ 115.000** = «Efectivo contado» (US4-1/3, FR-021).
2. Cierre con faltante (caso 3.2): desglose + diferencia `-$ 5.000` resaltada como faltante (US4-2).
3. Desde el histórico (administrador), abrir un turno **histórico sin desglose** → mensaje exacto
   «No se registró desglose para este turno», efectivo contado y diferencia visibles, **sin** línea
   «Contado por» y sin errores en consola (US5-1/4). Abrir uno con filas → tabla con tipo (US5-2).
4. «Imprimir / Exportar reporte» → en la vista previa de impresión aparece la tabla (o el mensaje) y
   **ninguna fila queda cortada entre páginas** (US6-3/4, SC-005). Probar con un desglose de 11 filas.
5. Revisión visual con DevTools (claro/oscuro) y a ancho móvil: la tabla no desborda.

## 9. Regresión (Principios III y X)

1. Backend: suite completa (paso 0.1) → **sin fallos nuevos**; las pruebas adaptadas citan D-1/D-2.
2. Frontend: suite del módulo `cash-register` en verde; suite completa → mismo conjunto de fallos
   preexistentes que la línea base del paso 0.2, **ninguno nuevo**.
3. `app/scripts/e2e_qr_flow.py` (adaptado al nuevo contrato) → termina OK.
4. Spec 119: el bloqueo por pedidos activos (caso 3.12) y el reporte operativo por turno
   (`/cash/shifts/{id}/sales-report`) siguen igual.
5. Confirmar que ningún test `"CONGELA comportamiento actual:"` quedó en rojo sin decisión que lo
   ampare (Principio III).

## Criterios de salida

Todos los escenarios anteriores pasan; SC-001 a SC-008 verificados; el `md5` del paso 0.3 coincide
antes y después de la migración; el recuento de pruebas es el de la línea base **más** las nuevas.
