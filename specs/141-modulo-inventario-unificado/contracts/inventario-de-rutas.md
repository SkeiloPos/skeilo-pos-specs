# Contrato: inventario de rutas gobernadas por módulo (SC-001)

**Spec**: [spec.md](../spec.md) (FR-002, FR-003, FR-004, SC-001) · **Research**: [D3](../research.md)

Cada funcionalidad pertenece a **un solo** módulo (FR-002). Esta tabla es el contrato que la prueba
`test_module_route_inventory.py` recorre sobre `app.routes`: toda ruta cuyo camino empiece por un prefijo de la columna
«Prefijo» **debe** llevar la dependencia del módulo de la columna «Módulo»; una ruta nueva bajo ese prefijo sin la dependencia
hace fallar la prueba. Los conteos son de `develop` a 2026-10-31.

## Módulo `inventario` — 43 rutas

| Prefijo (`/api/v1…`) | Rutas | Qué cubre | Estado antes | Cambio |
|---|---:|---|---|---|
| `/inventory/items…` | 13 | insumos: listar, `low-stock`, `export`, importar (`import`, `import/current`, `import/{job}`, `…/cancel`, `…/errors`), detalle, crear, editar, `adjust`, `movements` | gate `inventario` (router) | — |
| `/inventory/suppliers…`, `/inventory/items/{id}/suppliers`, `/inventory/suppliers/{id}/items`, `/inventory/supplier-items/{id}` | 8 | **Proveedores** y vínculos insumo-proveedor | gate `inventario` (router) | — (en el **front** sí faltaba la guardia) |
| `/inventory/purchases…` | **8** | **Compras**: listar, crear, orden, `PUT` ×2, `receive`, `void`, `DELETE` | gate `inventario` **+ `compras`** | **se quita el gate `compras`** |
| `/unit-measures…` | 6 | unidades de medida (`GET` ×2, `POST`, `PATCH`, `factor-changes`, `DELETE`) | gate `inventario` (router) | — |
| `/unit-measure-groups…` | 6 | grupos de unidades (`GET`, `POST`, `…/units`, `PATCH`, `…/base-unit`, `DELETE`) | gate `inventario` (router) | — |
| `/reports/inventory` | 1 | reporte de inventario (RF-063) | gate `inventario` (ruta) | — |
| `/reports/profitability` | 1 | rentabilidad (RF-065) | gate `inventario` (ruta) | — |
| **Total** | **43** | | | |

El router `/inventory` tiene **29** rutas (13 + 8 + 8). Los demás reportes (`/reports/sales`, `/products`, `/top-products`,
`/categories`, `/cashiers`) **no** pertenecen a ningún módulo (ventas): no llevan la dependencia.

## Módulo `promociones` — 7 rutas

| Prefijo | Rutas | Qué cubre |
|---|---:|---|
| `/promotions…` | 7 | `GET`, `POST`, `PATCH /{id}`, `PATCH /{id}/shape`, `PATCH /{id}/status`, `POST /{id}/duplicate`, `DELETE /{id}` |

`GET /menu/promotions` (anuncios del menú público) **no** pertenece al módulo: es ruta pública del comensal (Edge Case de la spec).

## Superficies de campo (no son rutas del módulo; se conservan)

Siguen funcionando sin el módulo y solo gobiernan **un campo** (spec 064/123, FR-011). Hoy usan `ensure_module_access`/
`has_module_access`; con la 141 lanzan `ModuleNotInPlanError` con el mismo cuerpo:

| Dónde | Campo / regla |
|---|---|
| `products/service.py:213,316` | `tracks_inventory = true` exige el módulo |
| `catalog/router.py:396,476` | `Option.inventory_item_id` exige el módulo |
| `orders/additions.py`, `orders/toppings.py`, `orders/consolidation.py`, `sales/complementary.py` | `has_module_access(…, "inventario")`: si no hay módulo, **no se descuenta stock** (no lanzan) |
| **`products/import_.py`, `products/export.py`** | **Hoy sin compuerta** (research H3). Ver D13: se gobiernan a nivel de campo en el incremento I7 |

## Comprobación de la prueba

```text
para cada (módulo, prefijos) en TABLA:
    rutas = [r for r in app.routes if r.path arranca por algún prefijo]
    assert len(rutas) == conteo_esperado[módulo]        # detecta rutas añadidas/quitadas sin actualizar el contrato
    para cada r en rutas:
        assert existe dep en r.dependant.dependencies con dep.call.module_key == módulo
para cada ruta r fuera de TABLA:
    assert no lleva ninguna dependencia de módulo       # una ruta no puede gobernarla un módulo «por accidente»
```

Cualquier cambio legítimo del inventario de rutas obliga a actualizar esta tabla y el conteo en el mismo commit (trazabilidad,
Principio XII).
