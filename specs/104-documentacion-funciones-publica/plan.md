# Implementation Plan: SRS por ingeniería inversa de SkeiloPOS (IEEE 830)

**Branch**: `104-documentacion-funciones-publica` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/104-documentacion-funciones-publica/spec.md`

## Summary

Producir, mediante ingeniería inversa de solo lectura sobre `pos-backend` (FastAPI + SQLAlchemy +
PostgreSQL) y `pos-heladeria` (Angular), una Especificación de Requisitos de Software (SRS) en
formato IEEE 830-1998 con equivalencias a ISO/IEC/IEEE 29148:2018. El proceso tiene cuatro fases
secuenciales (inventario de backend, inventario de frontend, cruce front↔back con punto de parada
obligatorio, redacción del SRS completo) y una regla central: toda afirmación lleva exactamente
una etiqueta de evidencia (`[CÓDIGO]`/`[INFERIDO]`/`[PREGUNTA]`, sintaxis fijada en
`contracts/formato-etiqueta-evidencia.md`). Los artefactos intermedios de las tres primeras fases
viven en esta misma carpeta de spec; el SRS confirmado se entrega en la carpeta nueva `srs/` en la
raíz del repositorio (Decisión 1-2 de `research.md`). Esta función **no modifica código** de
`pos-backend` ni `pos-heladeria` (FR-024): es análisis y contenido, no implementación.

## Technical Context

**Language/Version**: Markdown (CommonMark) para todos los entregables; no hay runtime ni
lenguaje de programación propio de esta función. El análisis lee (sin ejecutar) código en Python
3.12 (`pos-backend`) y TypeScript 5.9 (`pos-heladeria`).

**Primary Dependencies**: Ninguna dependencia nueva de producción ni de desarrollo en ningún
repositorio. El proceso usa únicamente herramientas de búsqueda de texto ya disponibles
(`grep`/`rg`) sobre el código fuente existente de `pos-backend` y `pos-heladeria` (Principio IX:
no aplica adopción de dependencia, solo lectura).

**Storage**: Archivos planos `.md` — artefactos intermedios en
`specs/104-documentacion-funciones-publica/` y entregable final en `srs/` en la raíz de
`pos-specs`. No aplica base de datos ni almacenamiento de aplicación; no se ejecuta ningún query
contra la base de datos real de `pos-backend`.

**Testing**: Sin tests automatizados de contenido. La verificación son los 7 pasos de
`quickstart.md` (muestreo de citas de evidencia contra el código real, verificación de cobertura,
verificación del punto de parada), más los tests existentes de ambos repositorios usados como
*fuente de evidencia* del comportamiento intencionado (FR-007) — nunca como artefacto que esta
función modifique o ejecute.

**Target Platform**: N/A — no hay runtime propio. Los sistemas analizados corren en sus
plataformas reales (API en contenedor, SPA servida estáticamente), pero esta función no los
despliega, ejecuta ni instrumenta: es análisis estático de su código fuente en el estado en que se
encuentra en el checkout local.

**Project Type**: Análisis/documentación técnica (ingeniería inversa). No aplica ninguna de las
estructuras estándar de proyecto de software (sin frontend, backend ni CLI propios de esta
función).

**Performance Goals**: N/A — no aplica a un proceso de análisis y redacción de contenido.

**Constraints**: Solo lectura sobre `pos-backend`/`pos-heladeria`, sin excepción (FR-024); cada
afirmación etiquetada sin excepción (FR-014); ninguna métrica no verificable registrada como hecho
(FR-015); ningún comportamiento defectuoso normalizado como requisito (FR-016); parada obligatoria
entre el cruce front↔back y la redacción del documento completo, con confirmación expresa del
usuario (FR-020); ningún secreto, credencial o token real expuesto al documentar configuración
(FR-006).

**Scale/Scope**: medido por lectura directa el 2026-10-08 (ver tabla completa en `research.md` §
Resumen de alcance verificado) — `pos-backend`: 30 módulos de router, ~168 endpoints, 40 modelos,
134 archivos de characterization tests; `pos-heladeria`: 20 módulos de feature, 121 archivos
`*.spec.ts`. El SRS final se organiza en 1 documento principal (`srs/README.md`) + 5 apéndices
independientes (`srs/apendices/`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ Cumple — `spec.md` existe, con su checklist de calidad en 18/18 (`checklists/requirements.md`), reemplazando por completo el alcance anterior de esta misma spec. |
| II. Comportamiento existente protegido | ✅ N/A — FR-024 exige análisis estrictamente de solo lectura; esta función no modifica, ejecuta ni altera ningún archivo de `pos-backend` ni `pos-heladeria`. |
| III. Characterization tests | ✅ N/A — ningún test `"CONGELA comportamiento actual:"` se toca; esos tests se usan como *fuente de lectura* (FR-007), nunca se modifican. |
| IV. Nuevos specs pueden introducir comportamiento | ✅ N/A — no se introduce comportamiento de aplicación; el SRS documenta comportamiento ya existente y verificado. |
| V. Sin refactors oportunistas | ✅ Cumple — alcance limitado a artefactos nuevos en `specs/104-.../` y `srs/`; cero cambios de código. |
| VI. Evolución incremental | ✅ Cumple — cuatro fases secuenciales con punto de parada explícito entre la fase 3 y la 4 (FR-020), cada una con su propio artefacto verificable. |
| VII. Compatibilidad con datos históricos | ✅ N/A — no hay datos ni facturas involucrados; el análisis no toca la base de datos real. |
| VIII. Evolución del modelo de datos | ✅ N/A — no hay cambio de esquema; el "modelo de datos" de este plan (`data-model.md`) describe entidades de contenido del propio SRS, no un cambio de base de datos. |
| IX. Dependencias nuevas justificadas | ✅ Cumple — cero dependencias nuevas en ningún repositorio; solo herramientas de búsqueda de texto ya presentes en el entorno. |
| X. Verificación obligatoria | ✅ Cumple — `quickstart.md` define 7 pasos de verificación que cubren SC-001 a SC-006, incluida la verificación explícita del punto de parada (paso 3). |
| XI. Decisiones de negocio vs. técnicas | ✅ Cumple — la ubicación del entregable (`srs/` en la raíz) es una decisión técnica de esta fase de planificación, explícitamente delegada a ella por el propio spec (sección Assumptions); no hay decisión de negocio pendiente en este plan. |
| XII. Trazabilidad | ✅ Cumple — cada Requisito lleva campo "Trazabilidad" obligatorio (FR-017) hacia endpoint/pantalla/entidad, consolidado en el Apéndice A (`contracts/estructura-srs-ieee830.md`). |
| XIII. Todo en español de Colombia | ✅ Cumple sin excepción — a diferencia del alcance anterior de esta spec (que distinguía español neutro para `docs-publicos/`), el SRS es un artefacto interno: se escribe íntegramente en español de Colombia, igual que este plan, `research.md`, `data-model.md` y `quickstart.md` (Decisión 6 de `research.md`). |
| XIV. Ramas Git | ✅ N/A — aplica solo a cambios de código en `pos-backend`/`pos-heladeria`; esta función no toca ninguno de los dos repos y no abre rama en ellos. |
| XV. Política de commits | ✅ Se aplicará en implementación — commits en `pos-specs` solo bajo pedido explícito del usuario, pequeños y por fase/artefacto, en inglés, Conventional Commits, sin atribución de IA. |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

*(Re-evaluado tras el diseño de Fase 1: ningún hallazgo de `data-model.md`, `contracts/` ni
`quickstart.md` introduce una violación nueva; el gate se mantiene en verde.)*

## Project Structure

### Documentation (this feature)

```text
specs/104-documentacion-funciones-publica/
├── plan.md                    # Este archivo (/speckit-plan)
├── research.md                # Fase 0 (/speckit-plan)
├── data-model.md               # Fase 1 (/speckit-plan)
├── quickstart.md               # Fase 1 (/speckit-plan)
├── contracts/                  # Fase 1 (/speckit-plan)
│   ├── formato-etiqueta-evidencia.md
│   ├── plantilla-requisito.md
│   ├── plantilla-hallazgo.md
│   └── estructura-srs-ieee830.md
├── checklists/
│   └── requirements.md         # Ya generado (/speckit-clarify o checklist previo)
├── inventario-backend.md       # Fase 2 (US1 — producido durante /speckit-implement)
├── inventario-frontend.md      # Fase 2 (US2 — producido durante /speckit-implement)
├── cruce-front-back.md         # Fase 2 (US3 — producido durante /speckit-implement; termina en el punto de parada)
└── tasks.md                    # Fase 2 (/speckit-tasks — no se crea en este comando; el tasks.md actual en esta carpeta corresponde al alcance anterior y debe regenerarse)
```

### Entregable final (repositorio raíz)

```text
srs/
├── README.md                          # Introducción, Descripción general, Requisitos específicos (US4)
└── apendices/
    ├── a-trazabilidad.md
    ├── b-equivalencia-normas.md
    ├── c-preguntas-abiertas.md
    ├── d-discrepancias.md
    └── e-cobertura.md
```

**Structure Decision**: análisis/contenido-solamente, sin `src/`, `backend/` ni `frontend/`
propios (no aplica ninguna de las opciones estándar de código del template — esta función no
produce software). Los artefactos de ejecución de las User Stories 1-3 (inventarios y cruce) viven
junto a los demás artefactos de planificación de esta spec, en
`specs/104-documentacion-funciones-publica/`, porque son el resultado directo de *esta* spec. El
entregable final (el SRS confirmado) vive en `srs/` en la raíz del repositorio, separado de la
carpeta de la spec, siguiendo el mismo precedente que `docs-publicos/` (entregable de otra spec
distinta, también en la raíz) — ver Decisión 1 y 2 de `research.md` para el razonamiento completo.

**Nota sobre `tasks.md` existente**: la carpeta ya contiene un `tasks.md` producido para el
alcance anterior de esta spec (documentación pública función por función). Ese archivo queda
obsoleto con este plan y debe regenerarse con `/speckit-tasks` antes de iniciar la implementación;
este comando (`/speckit-plan`) no lo toca ni lo borra.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no requerida.*
