# Data Model: Módulo Inventario unificado

**Spec**: [spec.md](./spec.md) · **Research**: [research.md](./research.md) (D4, D5) · **Fecha**: 2026-10-31

Este cambio **no crea entidades** y **no toca datos de los negocios**. Modifica una sola tabla compartida
(`shared.plans`) y retira un atributo. Todo lo demás —insumos, movimientos, proveedores, vínculos insumo-proveedor,
compras, órdenes de compra, importaciones— se conserva íntegro (FR-018) y vive en los esquemas de cada tenant, que esta
migración **no recorre**.

## 1. `shared.plans` — de tres accesos a módulo a dos

| Columna | Antes | Después | Notas |
|---|---|---|---|
| `inventario_access` | `boolean NOT NULL DEFAULT false` | **igual** | Pasa a significar «Inventario + Proveedores + Compras» (indivisible) |
| `compras_access` | `boolean NOT NULL DEFAULT false` | **se elimina** | Su valor se absorbe en `inventario_access` antes del `DROP` |
| `promociones_access` | `boolean NOT NULL DEFAULT false` | **igual** | Sin cambios |
| `*_limit`, `precio_*`, `name`, `description`, `id`, `created_at`, `updated_at` | — | **sin cambios** | FR-020: la migración no los altera |

Modelo ORM (`app/models/plan.py`): se elimina el atributo `compras_access`; el docstring pasa de «tres accesos de módulo» a
«dos». Sin `server_default` nuevo: `inventario_access` ya lo tiene.

### Regla de migración (por plan)

| Estado antes (`inventario`, `compras`) | Estado después `inventario` | ¿Gana o pierde acceso? |
|---|---|---|
| (no, no) | no | igual |
| (no, **sí**) | **sí** | conserva Compras; **gana** Inventario y Proveedores (Escenario 1, US1.1) |
| (sí, no) | sí | **gana** Proveedores y Compras — decisión de negocio 2, aceptada tal cual (US1.3) |
| (sí, sí) | sí | igual (US1.2) |

Ningún estado **pierde** acceso (FR-020, SC-006). `promociones_access` no interviene.

### Invariantes que la migración debe cumplir (verificables antes/después)

1. `count(*)` de `shared.plans` idéntico.
2. Para todo plan: `name`, `*_limit`, `precio_mensual`, `precio_anual`, `promociones_access` idénticos.
3. Para todo tenant: `tenants.plan_id`, `ciclo_facturacion`, `plan_iniciado_en`, `plan_vence_en` idénticos.
4. Para todo plan: `inventario_after = inventario_before OR compras_before`.
5. Los recuentos de `inventory_items`, `inventory_movements`, `suppliers`, `supplier_items`, `purchases`, `purchase_items`
   e `inventory_import_jobs` de cada esquema de tenant, idénticos (SC-006). La migración no abre esos esquemas.
6. Ejecutarla dos veces produce el mismo estado (idempotencia): el paso de datos se salta si `compras_access` ya no existe.

## 2. Migración Alembic

- **Archivo**: `pos-backend/alembic/versions/<hash>_141_plans_unify_inventory_module.py`.
- **`down_revision`**: `56a2cdbec89c` (cabeza actual, spec 144). **Volver a comprobar con `alembic heads` al implementar**: ramas de
  otras specs pueden haber movido la cabeza (research H4).
- **Esquema afectado**: solo `shared`. No usa `for_each_tenant_schema`.

```text
upgrade():
  si existe shared.plans.compras_access:
      UPDATE shared.plans SET inventario_access = true
        WHERE compras_access = true AND inventario_access = false
      ALTER TABLE shared.plans DROP COLUMN compras_access

downgrade():
  si NO existe shared.plans.compras_access:
      ALTER TABLE shared.plans ADD COLUMN compras_access boolean NOT NULL DEFAULT false
  UPDATE shared.plans SET compras_access = inventario_access
```

### Estrategia de reversión (Principio VIII) — qué se recupera y qué no

| Se recupera | No se recupera |
|---|---|
| La columna `compras_access` con su tipo, `NOT NULL` y `DEFAULT false` | El dato «este plan tenía Inventario **sin** Compras» |
| Que ningún plan quede con menos acceso que después del `upgrade` | El dato «este plan tenía Compras **sin** Inventario» |
| Los demás atributos del plan, intactos | La separación comercial previa entre Inventario y Compras |

Tras `upgrade` + `downgrade`: todo plan con Inventario queda con Compras. Efecto neto frente al estado original: los planes
(sí, no) ganan Compras; los (no, sí) quedan con (sí, sí). Es un enriquecimiento, nunca una pérdida (coherente con la decisión de
negocio 2). Se declara también en el docstring de la migración.

**Regla operativa de reversión de código** (el API ejecuta `alembic upgrade head` al arrancar): para volver a una imagen
**anterior** a la 141, primero `alembic downgrade -1`; una imagen anterior contra el esquema nuevo falla en la primera lectura de
`Plan` (el modelo viejo selecciona `compras_access`). Ver [quickstart.md](./quickstart.md) §Despliegue.

### Verificación contra PostgreSQL real

El paso de datos se escribe como función pura (`merge_compras_into_inventario(connection, schema="shared")`) que recibe una conexión y el
esquema; así se prueba en SQLite (`schema=None`) y se repite contra PostgreSQL real en una transacción que se revierte (`BEGIN … ROLLBACK`), como en las specs 138 y 140.
La BD de desarrollo tiene 1 plan (inventario=t, compras=t, promociones=t), por lo que la prueba real **siembra** las cuatro
combinaciones dentro de la transacción antes de ejecutar el paso.

## 3. Contratos que dejan de exponer `compras`

Detalle en [contracts/planes-api.md](./contracts/planes-api.md).

| Superficie | Cambio |
|---|---|
| `GET /api/v1/plan` → `modules` | `{ inventario, compras, promociones }` → `{ inventario, promociones }` |
| `GET /api/v1/bootstrap` → `plan.modules` | Igual (reutiliza `build_plan_summary`) |
| `GET/POST/PATCH /api/v1/super-admin/plans` | `compras_access` desaparece de petición y respuesta; en petición se **ignora** si llega |

## 4. Datos que **no** cambian (verificación explícita, FR-018)

| Dato | Dónde | Garantía |
|---|---|---|
| Insumos y movimientos | `inventory_items`, `inventory_movements` (esquema del tenant) | No se leen ni escriben en la migración; el gate solo impide el acceso mientras el plan no incluya el módulo |
| Proveedores y vínculos | `suppliers`, `supplier_items` | Ídem |
| Compras y órdenes | `purchases`, `purchase_items` | Ídem; un borrador u orden pendiente queda intacto y no se puede recibir/editar/anular hasta recuperar el módulo |
| Importaciones | `inventory_import_jobs` | Una en curso no se interrumpe; su resultado queda inaccesible hasta recuperar el módulo |
| Stock | `inventory_items.current_stock` | Al recuperar el módulo refleja el último estado registrado; no se concilian ventas hechas sin módulo |
| Facturas emitidas | `invoices*` | Fuera de alcance; Principio VII intacto |

## 5. Estado del cliente (sin persistencia)

Solo estado en memoria del front; nada se guarda en `localStorage`.

| Estado | Dónde | Vida |
|---|---|---|
| `PlanSummary.modules` | `PlanSummaryService.summary` (signal) | Sesión; se refresca por bootstrap, por la guardia y por el servicio de módulo perdido |
| «Atención de módulo perdido en curso» | `ModuleAccessLostService` (bandera interna) | Desde el primer `MODULE_NOT_IN_PLAN` hasta que terminan redirección y refresco del plan |

Transiciones del módulo en el resumen del plan del cliente:

```text
desconocido (summary = null)
   ├─ bootstrap/GET /plan → incluido ──────────────► incluido
   └─ bootstrap/GET /plan → no incluido ───────────► ausente
incluido ── 403 MODULE_NOT_IN_PLAN ──► (marca local) ausente ── refresco GET /plan confirma ──► ausente
ausente  ── recarga de la app tras reasignar el plan ──────────────────────────────────────────► incluido
```

Limitación conocida (igual que hoy con `vencido`): no hay empuje del servidor al reasignar un plan con el módulo; el cliente lo ve
en la siguiente recarga o en la siguiente navegación que pase por `planModuleGuard` (que ahora hidrata el resumen).
