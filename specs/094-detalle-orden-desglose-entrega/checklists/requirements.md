# Specification Quality Checklist: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Purpose**: Validar la completitud y la calidad de la especificación antes de pasar a la fase de plan
**Created**: 2026-10-03
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### Iteración 1 — 2026-10-03

17 de 18 ítems en verde. El único rojo fue "no quedan marcadores [NEEDS CLARIFICATION]": quedaban
tres, en FR-015 (Q1), FR-023 (Q3) y FR-024 (Q2) — el máximo permitido, y puestos a propósito porque
los tres se derivaban del reconocimiento del código y de los datos reales y ninguno tenía un valor
por defecto defendible sin decisión de negocio.

### Iteración 2 — 2026-10-03 — 18 de 18 en verde

Las tres preguntas se presentaron al solicitante y se resolvieron en la misma sesión. Las respuestas
quedaron registradas en *Clarifications → Session 2026-10-03* y los marcadores se sustituyeron por
requisitos cerrados:

- **Q1 → reusar lo que ya existe.** FR-015 queda con los cuatro campos del bloque de entrega
  mapeados a datos ya persistidos (nombre del cliente, teléfono y dirección de entrega, nota del
  pedido), más FR-015a: no se crea ningún campo. Consecuencia aceptada y registrada: una nota
  dirigida a cocina aparecerá bajo las referencias de entrega; separarlas está en *Fuera de Alcance*.
- **Q2 → factura 1:1 manda, si agrupa se avisa.** FR-024 (desglose leído de la factura cuando cubre
  solo ese pedido), FR-024a (desglose propio + aviso cuando agrupa varios) y FR-024b (la distinción
  la resuelve el servidor, no el navegador).
- **Q3 → sin fila de descuento, con aviso.** FR-023: `Total = Subtotal + Envío` y aviso de que el
  descuento se fija al cobrar; prohibido consultar el motor de cobro desde esta pantalla.

Cambios derivados aplicados en la misma iteración: tres escenarios de aceptación nuevos en US1
(§7 factura 1:1, §8 factura agrupada, §9 pedido sin cobrar), dos *Edge Cases* reescritos como
comportamiento definido, la tabla de trazabilidad actualizada (criterio 10 ya no está pendiente),
*Impacto sobre Datos Existentes* reducido a "ninguna migración de ningún tipo", y dos entradas
nuevas en *Fuera de Alcance* y en *Decisiones de Diseño Ya Confirmadas*.

### Iteración 3 — 2026-10-03 — 16 de 16 en verde (sin cambios de estado)

Segunda sesión de `/speckit-clarify`. Cinco preguntas más (Q4 a Q8), ninguna originada en un marcador
[NEEDS CLARIFICATION] —no quedaba ninguno— sino en tres contradicciones internas y dos decisiones que
el spec declaraba pendientes. Ningún ítem del checklist cambió de estado: los 16 ya estaban en verde y
siguen en verde. Lo que cambió es la calidad de lo que afirman.

- **Q4 → una sola pantalla, el mesero ve el desglose.** Cierra la única decisión abierta del spec.
  **A-107 pasa de ABIERTA a CERRADA** en `registro-de-anomalias.md`, con el fundamento verificado en
  código: el mesero entra a la terminal de mesas con los mismos permisos, y ahí ya ve importes y
  totales, así que el desglose no le expone información nueva. RN-007 queda confirmado.
- **Q5 → las líneas van a precio de lista; el descuento solo en el resumen.** Resuelve una
  contradicción que habría llegado a implementación: FR-002 pedía el importe ya descontado, FR-005
  definía el Subtotal como la suma de las líneas y FR-024 manda leer el desglose de la factura, cuyo
  subtotal es el de lista con el descuento aparte. Tal cual estaba, sumar las líneas no daba el
  Subtotal y el descuento se restaba dos veces. Reescritos FR-002 y FR-004, precisado FR-005, añadido
  **SC-007** (la aritmética visible cuadra) y corregidas la Decisión de Diseño 1 y el hallazgo del
  reconocimiento (de los cinco campos por línea, la pantalla usa tres).
- **Q6 → condición exacta del aviso legacy.** FR-018 declaraba que su condición era un requisito y no
  la enunciaba, así que no era testeable. Ahora dispara solo con al menos una línea no anulada cuya
  suma de importes de lista sea `$ 0`, con tres exclusiones explícitas. US3 pasa de 2 a 4 escenarios.
- **Q7 → los ítems anulados se muestran, marcados y sin importe cobrable.** El spec decía que mostrarlos
  "es decisión de presentación" y la dejaba sin tomar, pero no era neutral: decidía si la suma visible
  cuadra con el Subtotal. Añadido **FR-019a** y un escenario US1 §10 para el caso mixto.
- **Q8 → textos literales de los dos avisos.** Eran los únicos mensajes de la pantalla sin redacción
  fijada, mientras FR-017 y FR-018 sí la traían; US1 §8 y §9 verificaban "un aviso" sin poder comprobar
  cuál. Fijados en FR-023 y FR-024a y reflejados en los escenarios.

Nota de alcance: Q5 a Q8 son decisiones internas del spec (contradicciones y precisión de requisitos),
no discrepancias entre código y comportamiento documentado, así que **no** generan entradas `A-NN`
nuevas; viven en *Clarifications*. La única entrada del registro que se tocó es A-107.

### Observaciones que no bloquean

- La trazabilidad de los 14 criterios de aceptación del brief está en la tabla
  *Trazabilidad de los criterios de aceptación del brief* de `spec.md`: **14 de 14 cubiertos**, con
  el criterio 10 cubierto por construcción cuando la factura es 1:1 y con aviso explícito cuando
  agrupa varios pedidos.
- El brief suponía un caso legacy más amplio que el real. FR-018 acota la condición que dispara el
  aviso "Esta orden no tiene el detalle de precios por ítem" para que no se muestre en la mayoría de
  pedidos (que simplemente no tienen descuento).
- La spec amplía el brief en tres puntos que el reconocimiento hizo inevitables, todos registrados:
  el rol Mesero queda alcanzado (misma pantalla, mismos permisos), los ítems anulados no pueden
  sumar al total (FR-019), y el descuento de varias promociones a la vez necesita una regla de
  etiquetado (FR-010).
- **Registro de anomalías, hecho (2026-10-03)**: las tres decisiones de negocio y el hallazgo del
  alcance quedaron en `specs/000-reconocimiento/registro-de-anomalias.md` como **A-104** (Q1, reusar
  nombre del cliente y nota del pedido), **A-105** (Q2, factura 1:1 manda y aviso cuando agrupa),
  **A-106** (Q3, pedido sin cobrar sin fila de descuento) y **A-107** (el Detalle de Orden es una sola
  pantalla y el Mesero verá el desglose monetario). **Ninguna queda abierta**: A-107 se cerró en la
  iteración 3 con la decisión de Q4 (una sola pantalla para los tres roles). El spec no arrastra
  decisiones de negocio pendientes.
