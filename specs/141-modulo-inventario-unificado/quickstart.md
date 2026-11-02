# Quickstart: validación del módulo Inventario unificado

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Contratos**: [contracts/](./contracts/)

Guía de **validación**, no de implementación. Cada escenario cita la historia de la spec que prueba y la superficie de
[contracts/](./contracts/) que fija. Los pasos Q1–Q6 se automatizan en la suite; Q7–Q12 son recorridos con la aplicación.

## Prerrequisitos

| Qué | Cómo |
|---|---|
| Ramas | `feat/141-unified-inventory-module` en `pos-backend` y `pos-heladeria`, creadas desde `develop` antes de tocar código (Principio XIV) |
| BD de desarrollo | Contenedor PostgreSQL `pos` (usuario `admin`, base `pos_db`). Hoy: 1 plan con los tres accesos en `true`, 3 tenants (`heladeria`, `skeilo`, `tenantlocal`), `alembic_version = 56a2cdbec89c` |
| API | `pos-backend`: `env/bin/python -m uvicorn app.main:app` **nativo** (el `.env` usa hosts `localhost`; el contenedor `pos-api` usa los hosts de Docker) |
| Frontend | `pos-heladeria`: `ng serve` apuntando a esa API |
| Negocio de prueba | En desarrollo, `tenantlocal`. `springfieldgranizados` (Escenario 1 de la spec) solo existe en el entorno desplegado: ahí se repite Q7 tal cual |
| Planes de prueba | Crear desde el panel Super Admin o por `psql`: **P-A** Inventario sí/Promociones sí, **P-B** Inventario no/Promociones no, **P-C** Inventario sí/Promociones no, **P-D** Inventario no/Promociones sí. Prefijo `[141-test]` en el nombre para limpiarlos después |

## Línea base (antes de cambiar nada)

```text
# Backend (cada archivo por separado; la suite completa tarda ~2 min y no debe correr junto a la del frontend)
env/bin/python -m unittest discover -s app/characterization_tests -p 'test_plan_*.py'     # hoy: 34 OK
env/bin/python -m unittest discover -s app/characterization_tests -p 'test_super_admin_plans.py'   # hoy: 5 OK
# Frontend: medir la suite completa UNA vez, sola; guardar los nombres de las pruebas que fallan
ng test
```

Registrar el resultado en `tasks.md` (T0xx). Los fallos del frontend se comparan **por nombre**, no por recuento.

## Q1 — Migración: las cuatro combinaciones (US1.1–US1.5, SC-006)

1. Contra PostgreSQL real, dentro de `BEGIN … ROLLBACK`: sembrar 4 planes `[141-test]` con (inventario, compras) = (no,no) (no,sí) (sí,no) (sí,sí).
2. Ejecutar el paso de datos de la migración (o `alembic upgrade head` dentro de la transacción de prueba).
3. **Esperado**: `inventario_access` = no, **sí**, sí, sí. `count(*)` de planes idéntico; `plan_id` de cada tenant idéntico; límites y precios idénticos.
4. Volver a ejecutar el paso → **sin cambios** (idempotencia).
5. `alembic downgrade -1` → la columna `compras_access` reaparece con `= inventario_access`; `alembic upgrade head` → mismo estado final.
6. Recuentos de insumos, movimientos, proveedores, compras y órdenes por esquema de tenant: idénticos antes y después.

## Q2 — El servidor rechaza todo el módulo (US2, SC-001)

Con un tenant en **P-B** y un token de Administrador:

```text
curl -s -H "x-tenant-host: <slug>" -H "Authorization: Bearer <token>" -i <api>/api/v1/inventory/suppliers
```

**Esperado**: `403` y cuerpo `{"detail":"Tu plan actual no incluye el módulo de inventario.","code":"MODULE_NOT_IN_PLAN","module":"inventario"}`.
Repetir con una ruta de cada fila de [inventario-de-rutas.md](./contracts/inventario-de-rutas.md) (la suite lo recorre completo: 43 + 7 rutas). Con un
cuerpo inválido en un `POST` → sigue siendo `403`, no `422`. Sin que cambie ningún recuento de tablas del negocio.

## Q3 — Con el módulo, todo funciona sin indicador de Compras (US2.3, SC-002)

Tenant en **P-C**: `GET /inventory/suppliers`, `GET /inventory/purchases`, `POST /inventory/purchases/order`,
`POST …/receive`, `POST …/void`, `DELETE …/{id}` responden con normalidad (antes: 403 si `compras_access` era `false`).

## Q4 — Precedencias (US2.5, US2.6)

- Tenant con `plan_vence_en` pasado y plan con el módulo → `403 "Tu plan venció…"` **sin** `code`.
- Cajero (sin permiso de rol) en un tenant **con** módulo → el 403 de rol de siempre, sin `code`.
- Tenant sin Promociones → `GET /promotions` → `MODULE_NOT_IN_PLAN` con `module: "promociones"`.

## Q5 — Un cambio de plan surte efecto en la siguiente petición (FR-005, US5.5)

1. Tenant en **P-C**; `GET /inventory/items` → 200.
2. Super Admin reasigna el tenant a **P-B**.
3. La **siguiente** `GET /inventory/items` → 403 `MODULE_NOT_IN_PLAN`. Cero peticiones permitidas después del cambio.
4. Reasignar **P-C**: los mismos datos reaparecen íntegros (US5.3–US5.4).

## Q6 — Contratos de planes (US1.6–US1.7, FR-019, FR-022)

- `GET /api/v1/plan` y `GET /api/v1/bootstrap` → `modules` con **solo** `inventario` y `promociones`.
- `GET /api/v1/super-admin/plans` → ningún objeto con `compras_access`; `POST`/`PATCH` con `compras_access` en el cuerpo → 2xx, campo ignorado.
- El esquema OpenAPI no contiene la cadena `compras_access`.

## Q7 — Menú y pantallas con y sin módulo (US3, SC-004)

| Tenant | Menú | Panel de inicio | Ajustes / Reportes / formularios |
|---|---|---|---|
| **P-A** (con módulo) | Sección «Inventario» con «Inventario» y «Proveedores»; en Inventario, pestaña «Compras» y vista de nueva compra; todo opera sin errores de permisos | Tarjeta «Stock bajo» si hay insumos bajo mínimo | Pestaña «Unidades de medida», bloque de stock bajo, campos de receta |
| **P-B** (sin módulo) | **Sin** «Inventario», **sin** «Proveedores» y **sin** el encabezado de sección | **Sin** tarjeta; en la pestaña Red de DevTools, **cero** peticiones a `/inventory/*` | Sin pestaña «Unidades», sin bloque de stock, sin campos de receta |

Repetir con la sesión de un tenant **recién cargado** (recarga dura en `/dashboard/products/new`, `/dashboard/ajustes/grupos-opciones`,
`/dashboard/mesas-sesiones`): **cero** peticiones a `/unit-measures`, `/inventory/*` o `/promotions` cuando el módulo no está, y el
formulario/terminal cargan completos (research H1/H2).

## Q8 — URL directa a una pantalla no incluida (US4, SC-005)

Sin el módulo, pegar en la barra: `/dashboard/proveedores`, `/dashboard/proveedores/<id>/detalle`, `/dashboard/inventario`,
`/dashboard/inventario/<id>/detalle`, `/dashboard/inventario/compras/nueva`, `/dashboard/ajustes/unidades`, `/dashboard/promotions`.
**Esperado en cada una**: no carga, aterriza en el inicio y aparece **un** aviso «Esta funcionalidad no está incluida en tu plan».
Con el plan **vencido**: vuelta al inicio **sin** ese aviso. Con el módulo: cargan normal.

## Q9 — Pérdida del módulo con la sesión abierta (US5, SC-003)

1. Sesión de Administrador abierta en `/dashboard/inventario` (varias listas se piden a la vez) de un tenant en **P-C**.
2. Super Admin lo pasa a **P-B**.
3. El administrador hace cualquier acción (cambiar de pestaña, buscar, recargar la lista).
4. **Esperado**: **un solo** aviso, **una sola** redirección al inicio, el menú ya sin el módulo, **sin recargar**. En DevTools: varias respuestas 403 `MODULE_NOT_IN_PLAN`, ningún aviso extra.
5. Una acción posterior no repite el aviso. Al recargar, el menú sigue sin el módulo.
6. Repetir con el módulo **Promociones** abierto en `/dashboard/promotions` (el aviso y la conducta son los mismos).
7. Con **dos pestañas** abiertas del mismo tenant: cada una se corrige con su siguiente petición.

## Q10 — Panel Super Admin (US1.6, US1.8, US1.9, SC-007)

- «Nuevo plan» y «Editar plan» muestran **un** interruptor «Inventario» (ayuda «Incluye Proveedores y Compras») y «Promociones»; ningún «Compras». La lista de planes tampoco lo muestra.
- Editar un plan con Inventario, **desmarcarlo** y Guardar → diálogo «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato». **Cancelar** → el plan no cambia (verificar con `GET`). **Confirmar** → se guarda.
- Editar sin tocar Inventario, crear un plan nuevo, o quitar solo Promociones → se guarda **sin** diálogo.

## Q11 — Ventas siguen funcionando sin el módulo (FR-011)

Tenant en **P-B**: crear un producto, tomar un pedido en la Terminal de mesas y cobrarlo. **Esperado**: todo funciona; no se descuenta
stock; no aparece ningún aviso de plan. Es la prueba de regresión de H1/H2.

## Q12 — Importación/exportación de productos (solo si D13 se ratifica)

Tenant en **P-B**: exportar productos → el libro **no** trae la hoja «Receta» ni la columna «Rastrea inventario»; importar un libro con
«Rastrea inventario = Sí» o filas de «Receta» → esas filas se rechazan con «Tu plan actual no incluye el módulo de inventario.» y el resto se procesa. Tenant en **P-A**: sin cambios.

## Verificación final

```text
env/bin/python -m unittest discover -s app/characterization_tests          # backend completo, SOLO
ng test                                                                    # frontend completo, SOLO; comparar por nombre contra la línea base
ng build                                                                   # cero lecturas de `compras` (el tipo ya no lo permite)
```

Cada recorrido manual (Q7–Q12) que no se pueda ejecutar queda anotado como pendiente en `tasks.md` con su motivo, no como «hecho».

## Despliegue y reversión

| Paso | Regla |
|---|---|
| Orden | **Backend primero** (la migración corre sola en `docker/api-entrypoint.sh`), frontend inmediatamente después. Entre ambos, un bundle viejo no ve `modules.compras` y oculta la pestaña «Compras» unos minutos; el frontend recarga solo al detectar versión nueva (spec 134). Lo inverso (frontend primero) dejaría a los planes sin Compras viendo una pestaña que responde 403 |
| Worker | Reiniciar `pos-worker` junto con la API: su imagen vieja conserva el modelo `Plan` con `compras_access` y fallaría si alguna tarea lee el plan (el entrypoint del worker no ejecuta migraciones) |
| Antes de desplegar | Anotar `select inventario_access, compras_access, promociones_access, count(*) from shared.plans group by 1,2,3` (insumo del informe de qué planes ganaron Proveedores y Compras; la spec lo acepta sin revisión individual) |
| **Revertir el código** | **Primero** `alembic downgrade -1`, **después** desplegar la imagen anterior. Una imagen anterior contra el esquema nuevo falla al leer `Plan` |
| Qué no se revierte | La información «tenía Inventario sin Compras» (data-model §2) |
