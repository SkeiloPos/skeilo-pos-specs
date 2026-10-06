# Feature Specification: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

**Feature Branch**: `097-categoria-nombre-productos`

**Created**: 2026-10-06

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección**, no una funcionalidad nueva desde cero. Igual
que las specs [072](../072-fix-deteccion-turno-caja/spec.md) y
[093](../093-cajero-carta-agotado/spec.md) (esta última es, de hecho, quien introdujo la columna
"Categoría" de "Carta del menú" que aquí se corrige), cita nombres de archivo, función y línea del
código actual (`pos-backend`/`pos-heladeria`) porque son el contrato observable que se está
corrigiendo, no una fuga de detalles de implementación. Es un defecto latente de corrección de
datos, no una decisión de negocio nueva: el nombre de categoría de un producto deja de resolverse
correctamente solo cuando el tenant supera el límite de paginación de otro endpoint, algo que
nunca fue una regla de negocio deliberada. No aplica una nueva entrada en
`registro-de-anomalias.md`: restaura el comportamiento pretendido (mostrar el nombre real de la
categoría), no cambia ninguna regla de negocio ya decidida.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: solicitado directamente por el
dueño/desarrollador del proyecto el 2026-10-06, como historia de usuario redactada para esta spec.
No reabre ninguna regla de negocio sobre el catálogo, las categorías ni los permisos de Cajero/
Administrador introducidos por la spec 093: el fix es exclusivamente sobre **cómo se resuelve** el
nombre de la categoría de un producto, no sobre qué datos puede ver cada rol ni sobre el contrato
de `GET /categories`, que permanece intacto para quienes lo usan hoy (selector del formulario de
producto, filtro de promociones y la propia pantalla de Categorías).

**Input**: User description (verbatim): "Como Administrador o Cajero que consulta 'Carta del
menú', quiero ver el nombre de la categoría de cada producto sin depender de una lista de
categorías cargada aparte en el cliente, para que el listado sea correcto incluso cuando el tenant
tiene muchas categorías, y no dependa de que otra pantalla ya haya cargado el catálogo."

**Causa raíz (confirmada leyendo el código real)**:

- `GET /categories` pagina con un tope duro de 100 resultados por página
  (`app/api/v1/categories/router.py:53`, `size: int = Query(20, ge=1, le=100)`), y el cliente web
  pide exactamente ese máximo en una sola página
  (`src/app/modules/categories/services/category.service.ts`, método que carga
  `allCategories()`).
- La pantalla "Carta del menú" (`products-page.component.ts:313-319` y `:348-350`) resuelve el
  nombre de la categoría de cada producto buscando `product.category_id` en un mapa construido a
  partir de esa misma lista acotada (`categoryMap`/`categoryName()`), en vez de recibirlo ya
  resuelto en la respuesta de `GET /products`.
- Consecuencia: en un tenant con más de 100 categorías activas, los productos cuya categoría cayó
  fuera de esa primera página se muestran con "—" en la columna Categoría, aunque la categoría
  exista y tenga nombre. El defecto es puramente de **cómo se entera el cliente del nombre**, no de
  que el producto no tenga categoría: `Product.category_id` es una columna `NOT NULL` con llave
  foránea a `categories.id` (`app/models/product.py:19-22`), así que todo producto activo siempre
  tiene una categoría real asociada.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el nombre real de la categoría de cada producto, sin importar cuántas categorías tenga el tenant (Priority: P1)

Un Administrador o un Cajero abre "Carta del menú" y, para cada producto del listado, ve el nombre
real de su categoría — nunca un guion ("—") por no haber alcanzado a cargar esa categoría en una
lista aparte. Esto se cumple sin importar cuántas categorías tenga el tenant, y sin que la pantalla
dependa de que alguna otra pantalla ya haya cargado el catálogo completo de categorías de antemano.

**Why this priority**: es la única historia de esta spec y la que resuelve directamente el defecto
reportado: la columna Categoría de "Carta del menú" (introducida por la spec 093) debe ser
correcta siempre, no solo mientras el tenant tenga 100 categorías activas o menos. A nivel de
negocio esta corrección se clasificó como **P2** (no bloquea el uso diario: la carta sigue siendo
usable con un "—" ocasional), pero dentro de esta spec es la única historia y por eso lleva P1.

**Independent Test**: en un tenant con más de 100 categorías activas, abrir "Carta del menú" y
verificar que ningún producto muestra "—" en la columna Categoría; por separado, consumir
`GET /products` directamente (sin pasar por la interfaz) y verificar que cada ítem trae
`category_name` junto a `category_id`, sin necesitar una segunda llamada a `GET /categories`.

**Acceptance Scenarios**:

1. **Given** un tenant con más de 100 categorías activas, **When** abro "Carta del menú", **Then**
   cada producto muestra el nombre real de su categoría, nunca "—".
2. **Given** consumo `GET /products` directamente (API, sin UI), **When** reviso la respuesta,
   **Then** cada ítem trae `category_name` junto a `category_id`, sin necesidad de una segunda
   llamada a `GET /categories`.
3. **Given** una categoría es renombrada, **When** vuelvo a listar productos (`GET /products` o
   recargar "Carta del menú"), **Then** el nuevo nombre aparece de inmediato — el dato no vive en
   ninguna caché del cliente que pueda quedar desactualizada.
4. **Given** estoy en "Carta del menú" con un tenant de 100 categorías o menos (el caso que hoy ya
   funciona), **When** reviso el listado, **Then** el comportamiento visible no cambia: sigo viendo
   el nombre real de cada categoría.

---

### Edge Cases

- ¿Qué pasa si la categoría de un producto está inactiva (soft-delete, `active=false`)? Sigue
  existiendo con su nombre; "Carta del menú" sigue mostrando ese nombre real, igual que hoy no
  oculta productos de categorías inactivas.
- ¿Qué pasa con un tenant que tiene 100 categorías activas o menos (la mayoría hoy)? No cambia nada
  observable: ya mostraban el nombre correcto porque entraban en la única página que el cliente
  pedía; esta corrección no depende de cuántas categorías haya para funcionar.
- ¿Qué pasa si dos productos distintos comparten la misma categoría? Ambos muestran el mismo nombre
  real, resuelto de forma independiente para cada producto (no hay un límite compartido entre
  productos, a diferencia del límite que tenía `GET /categories`).
- ¿Qué pasa con `GET /categories` y las pantallas que lo usan hoy (selector del formulario de
  producto, filtro de promociones, pantalla de Categorías)? No se tocan: siguen funcionando
  exactamente igual, con el mismo tope de paginación, porque esos casos de uso no dependen de
  "Carta del menú".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST incluir, en cada ítem devuelto por `GET /products` (listado) y
  `GET /products/{id}` (detalle), el nombre real de la categoría del producto (`category_name`)
  junto a su identificador (`category_id`), resuelto en el propio servidor.
- **FR-002**: La resolución de `category_name` NO MUST depender de que el cliente haya cargado
  previamente, por completo o parcialmente, una lista separada de categorías — debe funcionar para
  cualquier producto sin importar cuántas categorías existan en el tenant ni en qué orden o página
  habrían caído dentro de un listado paginado de categorías.
- **FR-003**: El listado de "Carta del menú" MUST mostrar, para cada producto, el nombre real de
  su categoría — nunca un marcador de "dato no disponible" — sin importar cuántas categorías
  activas tenga el tenant. (La vista de detalle de producto hoy no muestra la categoría en
  absoluto — una omisión preexistente de la spec 093, FR-017, independiente de esta corrección —
  por lo que esta spec no le exige mostrarla; sí exige que el dato ya viaje resuelto en la
  respuesta de `GET /products/{id}` para quien quiera consumirlo, FR-001.)
- **FR-004**: Cuando una categoría es renombrada, cualquier lectura posterior de productos
  (`GET /products`, "Carta del menú") MUST reflejar el nuevo nombre de inmediato, sin depender de
  ninguna caché del cliente que pueda quedar desactualizada.
- **FR-005**: El contrato de `GET /categories` (incluida su paginación con tope máximo de 100 por
  página) NO MUST cambiar — debe seguir funcionando exactamente igual para el selector del
  formulario de producto, el filtro de promociones y la propia pantalla de Categorías.

### Key Entities *(include if feature involves data)*

- **Producto**: ítem de la carta de un tenant. Gana un dato derivado de solo lectura,
  `category_name`, resuelto a partir de su `category_id` en el propio servidor; no se persiste por
  separado ni se desnormaliza en la tabla de productos.
- **Categoría**: ya existente; esta spec no le agrega ni le quita ningún atributo ni endpoint. Su
  nombre (`name`) es la fuente de verdad que `category_name` refleja.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los productos mostrados en el listado de "Carta del menú" muestran el
  nombre real de su categoría, incluso en tenants con más de 100 categorías activas.
- **SC-002**: El 100% de las respuestas de `GET /products` (listado y detalle) incluyen
  `category_name` junto a `category_id`, sin que el cliente necesite una segunda llamada a
  `GET /categories` para mostrar la carta correctamente.
- **SC-003**: Renombrar una categoría se refleja en el nombre mostrado para sus productos en la
  siguiente lectura de `GET /products` o recarga de "Carta del menú", sin ningún retraso atribuible
  a caché.
- **SC-004**: El 100% de las pantallas que ya usan `GET /categories` hoy (selector del formulario
  de producto, filtro de promociones, pantalla de Categorías) siguen funcionando sin ningún cambio
  observable en su comportamiento o contrato.

## Assumptions

- `Product.category_id` es una columna obligatoria (`NOT NULL`) con llave foránea a `categories`;
  todo producto existente tiene siempre una categoría real asociada, activa o inactiva. Esta
  corrección no contempla productos "sin categoría" porque ese estado no es alcanzable hoy.
- El diseño técnico concreto de cómo el servidor resuelve `category_name` (por ejemplo, un JOIN en
  la propia consulta de productos) se decide en la fase de planeación, no en esta spec; lo que esta
  spec fija es el contrato observable: el dato llega resuelto en la respuesta de productos, sin
  tope ligado a la paginación de categorías.
- `GET /categories` y su tope de 100 por página quedan fuera de alcance a propósito: ningún caso de
  uso existente (selector de categoría, filtro de promociones, pantalla de Categorías) depende de
  "Carta del menú" ni se ve afectado por este fix.
