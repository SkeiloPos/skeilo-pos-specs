# Cómo llenar la plantilla de Excel de Inventario

Referencia completa: [contracts/plantilla-excel-inventario.md](./contracts/plantilla-excel-inventario.md)

## Columnas (en este orden exacto)

| # | Columna | Obligatoria | ¿Qué hace? |
|---|---|---|---|
| 1 | Código | No (al crear) | Vacío = se asigna automático. Si ya existe, **actualiza** ese insumo (y entonces Unidad/Grupo/Unidad de compra/Factor se ignoran por completo). |
| 2 | Nombre | Sí | Nombre del insumo. |
| 3 | Tipo | Sí | `Materia prima` o `Empacado` (texto exacto). |
| 4 | Unidad | Sí (al crear) | Abreviatura de la unidad base (ej. `g`, `lt`, `un`). Si ya existe en el negocio, se reutiliza; si no, se crea. |
| 5 | Grupo | No | Nombre del grupo de medida (ej. `Masa`, `Volumen`). Vacío = se crea un grupo propio con el nombre de la Unidad. Si se indica, agrupa varias unidades compatibles entre sí (ver más abajo). |
| 6 | Stock | Sí | Cantidad actual, numérico. |
| 7 | Mínimo | Sí | Umbral de stock bajo, numérico. |
| 8 | Costo | Sí | Costo unitario, numérico. |
| 9 | Proveedor preferido | No | Nombre del proveedor. Si no existe, se crea. |
| 10 | Unidad de compra | No | Solo tiene efecto si también hay Proveedor preferido. Unidad en la que ese proveedor vende (ej. `KG` si tú manejas el insumo en `g`). |
| 11 | Factor de conversión (compra) | No | Cuántas unidades base trae 1 unidad de compra (ej. `1000` si 1 `KG` = 1000 `g`). Obligatorio si la Unidad de compra es nueva. |

## Reglas clave

- **Grupo** permite que una misma "familia" de unidades (ej. `g` y `KG`, ambas de masa) quede conectada, para que el sistema sepa convertir entre ellas.
- **Unidad de compra + Factor** solo se usan al **crear** un insumo nuevo, y solo si también traes el Proveedor preferido en la misma fila. Sirven para que, al comprarle a ese proveedor, el sistema convierta automáticamente de la unidad en que compras a la unidad en que llevas tu inventario.
- Si pones Unidad de compra pero **no** pones Proveedor preferido, la fila falla (no hay a quién asociarle esa unidad de compra).
- Actualizar un insumo existente (Código ya registrado) **nunca** toca Unidad/Grupo/Unidad de compra/Factor, aunque vengan llenas — solo se usan para dar de alta insumos nuevos.

## Ejemplo con 5 filas

| Código | Nombre | Tipo | Unidad | Grupo | Stock | Mínimo | Costo | Proveedor preferido | Unidad de compra | Factor de conversión (compra) |
|---|---|---|---|---|---|---|---|---|---|---|
| | Harina de trigo | Materia prima | g | Masa | 0 | 2000 | 4.5 | Molino XYZ | KG | 1000 |
| | Azúcar blanca | Materia prima | g | Masa | 0 | 1000 | 3.2 | | | |
| | Vaso desechable 8oz | Empacado | un | Unidades | 500 | 100 | 150 | Distribuidora Norte | Bulto | 50 |
| | Leche entera | Materia prima | lt | Volumen | 20 | 5 | 2800 | | | |
| 0001 | Harina de trigo | Materia prima | kg | Masa | 15 | 2 | 4500 | | | |

### Qué pasa con cada fila

1. **Harina de trigo**: insumo nuevo. Como el grupo "Masa" no existe todavía, se crea junto con la unidad base `g`. Como trae proveedor y unidad de compra, se crea también la unidad `KG` dentro de ese mismo grupo "Masa", con factor 1000 (1 KG = 1000 g) — queda lista para comprarle a "Molino XYZ" en KG aunque el inventario se lleve en gramos.
2. **Azúcar blanca**: insumo nuevo, sin proveedor ni unidad de compra. Como el grupo "Masa" ya existe (lo creó la fila 1), se reutiliza — la unidad `g` del grupo "Masa" también se reutiliza si ya existía, o se crea ahí mismo si no.
3. **Vaso desechable**: insumo nuevo con su propio grupo "Unidades". El proveedor "Distribuidora Norte" vende por "Bulto" (50 unidades por bulto) — se crea esa unidad de compra dentro del grupo "Unidades".
4. **Leche entera**: insumo nuevo, independiente, en su propio grupo "Volumen", sin proveedor preferido.
5. **Código `0001`**: como ya existe un insumo con ese código (la harina de la fila 1), esta fila lo **actualiza** — cambia Stock/Mínimo/Costo, pero las columnas Unidad (`kg`), Grupo (`Masa`) y las de unidad de compra se ignoran por completo, aunque estén llenas.

## Errores comunes que hacen fallar una fila

- Poner una Unidad que ya existe en el negocio pero en un Grupo distinto al indicado (ambigüedad: el sistema no sabe cuál usar).
- Poner una Unidad de compra que ya existe con un Factor distinto al que ya tiene esa unidad (no se puede pisar un factor vigente).
- Poner Unidad de compra sin Proveedor preferido en la misma fila.
- Dejar Unidad, Tipo, Nombre, Stock, Mínimo o Costo vacíos al crear un insumo nuevo.
