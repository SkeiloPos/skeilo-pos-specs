# Specification Quality Checklist: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Purpose**: Validar la completitud y la calidad de la especificación antes de pasar a la planificación
**Created**: 2026-10-05
**Updated**: 2026-10-05 (tras `/speckit-clarify` y la corrección de D2)
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

## Notas de la validación

**Estado final**: 16 de 16 ítems en verde. 60 requisitos funcionales, 13 criterios de éxito, 13
decisiones registradas, 0 marcadores de clarificación pendientes.

### Iteración 1 — correcciones de redacción

1. *Detalles de implementación en los requisitos*: varios FR citaban atributos y mecanismos
   concretos del navegador (`autocomplete="username"`, "eliminar del DOM", `aria-label`,
   `localStorage`). Se reescribieron en términos de comportamiento observable (FR-005, FR-016,
   FR-017, FR-022, FR-028), dejando el *cómo* para la planificación.
2. *Criterios de éxito con métricas técnicas*: se evitaron umbrales de latencia de red y se
   expresaron en términos de lo que el usuario logra (SC-001, SC-002, SC-009).
3. *Alcance implícito*: el pedido nombraba dos archivos de diseño, pero implicaba tres pantallas y
   arrastraba plantillas de correo y una pantalla de cambio de contraseña no solicitadas. Acotado
   en D9, D10 y D11.

### Iteración 2 — las tres decisiones de alcance quedaron resueltas

El negocio resolvió el 2026-10-05 las tres que estaban marcadas como pendientes:

- **D1 → solo correo electrónico**. El trabajo de autenticación no cambia; la etiqueta del campo se
  alinea al sistema en lugar de al mockup (FR-011a).
- **D2 → se corrigió a: no se expone ningún dato del negocio sin autenticación**. La etiqueta usa el
  identificador del subdominio (FR-007, FR-007a a FR-007d). La spec es **exclusivamente de
  frontend**; `pos-backend` no se toca.
- **D3 → el control "Mantener sesión iniciada" se maqueta sin efecto**. Se planteó la objeción de
  que un control de seguridad visible sin efecto puede inducir una creencia falsa en el usuario; el
  negocio la consideró y decidió incluirlo para no volver a tocar la pantalla cuando llegue la spec
  de sesión extendida. La decisión quedó acotada por FR-019a a FR-019e, que obligan al control a no
  hacer nada observable, y por D3a, que corrige su etiqueta porque la del mockup ("Recordar
  contraseña") afirmaría algo que la propia spec prohíbe.

### Iteración 3 — `/speckit-clarify` y corrección de D2

Durante la sesión de clarificación, el negocio corrigió D2 de "exponer una consulta pública de
identidad" a "no exponer ningún dato del negocio". La corrección invalidó tres clarificaciones ya
integradas —datos del endpoint, límite de solicitudes y registro de consultas fallidas—, que se
retiraron junto con los requisitos derivados (antiguos FR-007a a FR-007i, FR-009b, FR-010a,
FR-010b, SC-012a, SC-012b). La sección `## Clarifications` deja constancia de esa retirada para que
no se lea como una pérdida accidental.

Clarificaciones que sobreviven en la spec: 2 (origen de la etiqueta, formato del identificador).

### Hallazgos de código que corrigieron la spec

1. **Clasificación de hosts**: el mecanismo vigente (spec 091) trata **cualquier** subdominio no
   reservado como tenant válido. El Escenario 3 del pedido —subdominio no registrado muestra "No
   encontramos este negocio"— solo es alcanzable preguntando al servidor, que es justo lo que D2
   descartó. Queda como **limitación conocida y aceptada** en D12 y FR-009a, no como olvido.
2. **El modelo `Tenant` no tiene flag de activo/desactivado**: dos casos límite redactados sobre un
   "negocio desactivado" describían un estado inexistente. Se reemplazaron por el estado que sí
   existe, el plan vencido.
3. **Las páginas del sitio público ya existen** (`/privacidad` en `skeilo-pos-landing`), así que
   FR-003 y FR-009 solo las enlazan; FR-003a lo deja explícito.

### Riesgos conscientes que la implementación debe respetar

- **D2 renuncia a la fidelidad visual del mockup**: la etiqueta dirá `granizadosdelsol`, no
  "Granizados Del Sol", y FR-007 prohíbe embellecerlo. Si durante la implementación alguien
  "mejora" el texto capitalizándolo, está revirtiendo una decisión tomada.
- **D3 deja un control inerte en una pantalla de seguridad.** FR-019b a FR-019e son las barandas:
  si la implementación envía el estado al servidor, lo persiste, o lo etiqueta como si guardara la
  contraseña, la decisión deja de ser la que el negocio tomó.

**Estado**: lista para `/speckit-plan`. Al tocar un solo repositorio (`pos-heladeria`) y no haber
cambios de servidor, el plan puede organizarse por pantalla, entregando primero el inicio de sesión
(Historia 1, P1), que es la que bloquea la operación diaria.
