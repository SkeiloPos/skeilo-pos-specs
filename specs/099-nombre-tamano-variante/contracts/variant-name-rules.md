# Contrato: reglas del nombre propio de una variante + vectores de prueba compartidos

**Spec**: FR-001…FR-003, FR-007 | **Decisión**: [research.md](../research.md) D3, D4

Esta es la **única definición** de la regla. Se implementa dos veces —`app/core/variant_name.py`
(Python) y `src/app/shared/validators/variant-name.validator.ts` (TypeScript)— y **ambas suites de
prueba recorren la tabla de vectores de abajo** (mismas entradas, mismos resultados). Si una
implementación diverge, falla su prueba. Mismo patrón que
[full-name-rules.md](../../091-admin-subdominio-nombre-completo/contracts/full-name-rules.md)
(spec 091), adaptado a un campo **opcional** y sin restricción de alfabeto.

## Algoritmo

Entrada: texto o ausente/`null`.

1. **Preparar**: si es ausente/`null` → tratar como `""`.
2. **Longitud máxima**: contar **puntos de código** del valor de entrada (sin recortar ni
   colapsar todavía). Si supera 60 → error `length` (FR-007, Escenario 8 — se mide sobre el texto
   tal como se escribió, antes de normalizar).
3. **Normalizar**: `trim` (espacios Unicode en los extremos) y colapsar cada secuencia de uno o
   más espacios internos a un único espacio U+0020 (FR-002).
4. El resultado del paso 3 es el valor que se valida **y** el que se guarda — puede ser `""`
   (nunca `null`, FR-003). No hay regla de "obligatorio": `""` es un resultado válido.
5. **Sin restricción de alfabeto ni de longitud mínima**: a diferencia del nombre completo (spec
   091), cualquier carácter Unicode es aceptado (incluido HTML/script como texto — FR-011 lo
   escapa **al mostrarse**, no lo rechaza al guardarse).

Se devuelve el único error posible, `length`, si aplica; si no, el valor normalizado.

## Mensajes (español de Colombia)

| Error | Texto |
|---|---|
| `length` | `El nombre admite hasta 60 caracteres` |

En el servidor la excepción es `ValueError(<texto>)`, lanzada por el validador de Pydantic en
`VariantCreate`/`VariantUpdate`/`VariantSaveIn` (`app/api/v1/catalog/schemas.py`); Pydantic la
expone como `Value error, <texto>` en `detail[0].msg` (422). En el formulario se muestra el texto
sin prefijo, antes de intentar guardar (`canSave()`, research.md D9).

## Vectores de prueba (entrada → resultado)

`✓ valor` = válido, devuelve `valor` guardado (puede ser `""`). Los espacios visibles se muestran
con `·` donde importan.

| # | Entrada | Resultado |
|---|---|---|
| 1 | `Para compartir` | ✓ `Para compartir` *(Escenario 2)* |
| 2 | *(ausente / `null`)* | ✓ `""` *(Escenario 14)* |
| 3 | `""` (vacío) | ✓ `""` |
| 4 | `···` (solo espacios) | ✓ `""` *(Escenario 4)* |
| 5 | `··Para···compartir··` (espacios repetidos y en los extremos) | ✓ `Para compartir` *(Escenario 5)* |
| 6 | `a`×60 | ✓ igual (60 caracteres, en el límite) |
| 7 | `<b>x</b>` | ✓ `<b>x</b>` guardado tal cual — se escapa **al mostrarse**, no al guardarse *(Escenario 13)* |
| 8 | `a`×61 (sin espacios) | ✗ `length` *(Escenario 8)* |
| 9 | `··` + `a`×61 + `··` (61 + espacios en los extremos que luego se recortarían) | ✗ `length` (se mide el texto tal como se escribió, antes de recortar) |
| 10 | Cualquier emoji, dígito, símbolo o alfabeto no latino, dentro de 60 caracteres | ✓ igual — sin restricción de formato, a diferencia del nombre completo (spec 091) |

## Regla de unicidad dentro del producto (distinta de este contrato de formato)

El resultado normalizado de este contrato alimenta el cálculo de `display_name` (data-model.md), y
es `display_name` — no `name` crudo — lo que FR-008 exige único entre variantes **activas** del
mismo producto, con comparación insensible a mayúsculas. Esa regla vive en
[product-variants-api.md](./product-variants-api.md) §"Conflicto: nombre duplicado", no en este
contrato de formato.

## Uso por superficie

| Superficie | Opcionalidad | Fuente |
|---|---|---|
| `POST/PATCH /products` (variantes del árbol, servidor) | siempre opcional | `variant_name.normalize_variant_name` |
| `POST/PATCH /variants/{id}` (endpoints standalone, servidor) | siempre opcional | `variant_name.normalize_variant_name` |
| Formulario "Tamaños del producto" — campo "Nombre (opcional)" | siempre opcional | `normalizeVariantName` (validador en vivo, antes de habilitar "Guardar") |
