# Contrato: planes y resumen del plan (cambio incompatible, FR-019–FR-022)

**Spec**: [spec.md](../spec.md) · **Research**: [D4, D5](../research.md) · **Modelo**: [data-model.md](../data-model.md)

Los tres consumidores internos (panel Super Admin, «Mi plan» y menú/guardias del tenant) se actualizan en esta misma spec; la
spec declara que no hay consumidores externos. **Sin período de transición ni campo deprecado.**

## 1. `GET /api/v1/plan` (cualquier usuario autenticado del tenant)

```diff
 {
   "plan_name": "Pro",
   "ciclo_facturacion": "mensual",
   "plan_vence_en": "2026-11-30T00:00:00Z",
   "vencido": false,
   "resources": { "mesas": { "used": 3, "limit": 10 }, "...": {} },
   "modules": {
     "inventario": true,
-    "compras": true,
     "promociones": false
   }
 }
```

`ModuleAccess` (Pydantic) pasa de 3 a 2 campos. `GET /api/v1/bootstrap` incluye este mismo bloque en `plan` (reutiliza
`build_plan_summary`) y cambia igual.

## 2. `/api/v1/super-admin/plans` (solo Super Admin)

`GET` (lista), `POST` (crear) y `PATCH /{plan_id}` (editar):

```diff
 {
   "id": "…", "name": "Pro", "description": null,
   "mesas_limit": 10, "cajas_limit": 2, "usuarios_limit": 5,
   "productos_limit": null, "metodos_pago_activos_limit": 4,
   "inventario_access": true,
-  "compras_access": true,
   "promociones_access": false,
   "precio_mensual": "49000.00", "precio_anual": null,
   "created_at": "…", "updated_at": "…"
 }
```

| Operación | Comportamiento |
|---|---|
| `POST` / `PATCH` con `compras_access` en el cuerpo | **Se ignora** (Pydantic `extra="ignore"`): sin 422. Cubre pestañas con el bundle viejo (research H5) |
| `PATCH` con `inventario_access: false` sobre un plan que lo tenía | Se guarda; el efecto es inmediato para todos los negocios con ese plan (FR-014 de la spec 033). La **confirmación** vive solo en la UI (FR-019), no en el servidor |
| `POST` sin `inventario_access` | Default `false` (FR-002 de la spec 033) |

## 3. Catálogo de módulos (FR-001)

| Antes | Después |
|---|---|
| `inventario`, `compras`, `promociones` | `inventario`, `promociones` |

Una única constante en el backend (`PLAN_MODULES`) y un único tipo en el front (`ModuleAccess`). Cualquier clave fuera del catálogo
falla al construirse la dependencia (backend) o no compila (front).

## 4. Qué ve cada actor tras el cambio

| Actor | Antes | Después |
|---|---|---|
| Super Admin, crear/editar plan | 3 interruptores | **2** interruptores: «Inventario» (con ayuda «Incluye Proveedores y Compras») y «Promociones» |
| Super Admin, lista de planes | chips Inventario · Compras · Promociones | chips Inventario · Promociones |
| Super Admin, quitar Inventario a un plan existente | guarda directo | **Confirmación** con texto fijo (ver [frontend-acceso-modulos.md](./frontend-acceso-modulos.md) §6) |
| Tenant, «Mi plan» | lista 3 módulos | lista **2** módulos |
| Tenant sin Inventario | oculto en menú: solo «Inventario»; «Proveedores» visible | ocultos «Inventario» **y** «Proveedores» y el encabezado de sección |

## 5. Verificación

- Backend: `test_plan_summary.py` (sin `compras`), `test_super_admin_plans.py` (crear plan sin `compras_access`; enviar `compras_access` no rompe).
- Contra el esquema OpenAPI generado: ninguna ruta ni esquema menciona `compras_access` ni `modules.compras`.
- Frontend: `ModuleAccess` y `Plan`/`PlanCreatePayload` sin `compras`; `ng build` falla si queda alguna lectura (el tipo ya no la permite).
