# Quickstart: Rediseño del listado de la Carta del menú

**Feature**: `152-rediseno-listado-carta-menu` | **Date**: 2026-11-05

Guía de validación end-to-end una vez implementado el feature. No incluye código de
implementación — ver `contracts/get-products.md` y `data-model.md` para el detalle del
contrato y las reglas, y `tasks.md` (fase siguiente) para el desglose de trabajo.

## Prerrequisitos

- `pos-backend` corriendo localmente contra Postgres (ver memoria del proyecto: venv +
  comando de arranque habitual; Postgres local disponible).
- `pos-heladeria` corriendo con `ng serve`, apuntando al backend local.
- Un tenant con al menos:
  - 1 producto con una sola variante activa con precio > 0.
  - 1 producto con ≥2 variantes activas con precios distintos, todos > 0.
  - 1 producto sin ninguna variante con precio configurado (todas en 0 o inactivas).
  - 1 producto sin `image_url`.
  - Al menos 2 categorías distintas con productos.
- Usuario Admin y usuario Cajero para validar que ambos ven el listado (FR-011).

## Escenario 1 — Tarjetas en móvil/tablet (US1, FR-001, FR-007, SC-001)

1. Abrir el módulo "Carta del menú" con el viewport del navegador en 375px de ancho.
2. Confirmar que los productos se muestran como tarjetas (no tabla), sin scroll
   horizontal, cada una con: imagen o marcador "Sin imagen", nombre, categoría, precio
   (o "Sin precio"), badges de estado (Activo/Inactivo, Disponible/Agotado).
3. Repetir con el viewport en 900px (rango tablet) — debe seguir mostrando tarjetas, no
   tabla (Edge Case del spec).
4. Redimensionar a 1200px — debe aparecer la tabla de escritorio, con las mismas
   columnas/acciones que tenía antes del rediseño, más las columnas "Precio",
   "Creación" y "Actualización" (FR-002/FR-009): confirmar que el filtro de búsqueda y
   la página actual no se perdieron al cruzar el breakpoint.

## Escenario 2 — Filtro por categoría (US2, FR-003/FR-004, SC-003)

1. Con el listado cargado, seleccionar una categoría específica en el filtro.
2. Confirmar (en la pestaña Red del navegador o en logs del backend) que la petición a
   `GET /products` incluye `category_id` y que el listado resultante solo contiene
   productos de esa categoría.
3. Escribir además un término de búsqueda por nombre — confirmar que ambos filtros se
   combinan (AND), no que uno reemplaza al otro.
4. Volver a "Todas las categorías" — confirmar que el listado vuelve a mostrar todas las
   categorías, conservando la búsqueda por nombre si seguía activa.
5. Elegir una combinación de categoría + búsqueda que no tenga coincidencias — confirmar
   que se muestra el mensaje de "sin resultados" existente, no una lista vacía sin
   explicación (FR-010).

## Escenario 3 — Precio resumido por producto (US3, FR-005/FR-006, SC-002)

1. Ubicar en el listado el producto con una sola variante con precio — confirmar que se
   muestra su precio exacto, sin el prefijo "Desde".
2. Ubicar el producto con varias variantes con precios distintos — confirmar que se
   muestra el precio más bajo precedido de "Desde".
3. Ubicar el producto sin ningún precio configurado — confirmar que se muestra "Sin
   precio" (no "$0" ni un espacio vacío).
4. Verificar en los tres casos que el valor coincide con lo calculado manualmente a
   partir de las variantes activas de cada producto (consulta directa a
   `product_variants` o a `GET /products/{id}` para comparar).

## Escenario 4 — Payload mínimo del listado (FR-008, SC-004)

1. Con las herramientas de desarrollador del navegador, inspeccionar la respuesta cruda
   de `GET /products`.
2. Confirmar que ningún item incluye `description`, `tracks_inventory`, `is_topping`,
   `visible_en_qr` ni `available_changed_by_name` (ver contracts/get-products.md).
3. Confirmar que cada campo presente en la respuesta se renderiza en algún punto de la
   tarjeta o de la fila de tabla (inspección manual contra la plantilla renderizada).

## Escenario 5 — Preservación de acciones y roles (FR-011)

1. Iniciar sesión como Cajero: confirmar que el listado (tarjetas y tabla) sigue
   permitiendo marcar Disponible/Agotado, pero no editar ni activar/desactivar
   (comportamiento igual al actual).
2. Iniciar sesión como Admin: confirmar que además puede editar, activar/desactivar y
   usar "Nuevo producto"/"Exportar carta"/"Importar Excel", sin cambios funcionales
   respecto al listado anterior.

## Verificación automatizada mínima

- Backend: `pytest app/characterization_tests/test_product_list_pricing_and_category_filter.py`
  (nuevo, cubre D2/D3/D4 de research.md) + suite completa de characterization tests para
  confirmar ausencia de regresiones (`pytest app/characterization_tests/`).
- Frontend: `ng test` sobre `products-page.component.spec.ts` (actualizado) y el nuevo
  `product-list-card.component.spec.ts`.
