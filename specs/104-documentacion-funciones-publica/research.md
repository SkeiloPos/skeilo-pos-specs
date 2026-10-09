# Research: SRS por ingeniería inversa de SkeiloPOS (IEEE 830)

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-10-08

Esta función no introduce código ni cambia comportamiento de `pos-backend`/`pos-heladeria`
(FR-024: el análisis es de solo lectura). Su único entregable es un documento SRS en Markdown más
sus artefactos de apoyo (inventarios, cruce front↔back). Por eso, en vez de "elecciones
tecnológicas" en el sentido habitual, las decisiones de esta fase giran en torno a: dónde vive el
entregable final, cómo se cita evidencia de forma verificable, cómo se delimita el alcance de cada
pasada de análisis, y cómo opera en la práctica el punto de parada obligatorio del spec (FR-020).

## Decisión 1 — Ubicación del entregable final

**Decisión**: el documento SRS confirmado vive en una carpeta nueva en la raíz del repositorio,
`srs/`, paralela a `docs-publicos/` (que es un entregable de una spec distinta y no se toca). Los
artefactos de trabajo de las fases 1-3 (inventarios y cruce front↔back) viven dentro de
`specs/104-documentacion-funciones-publica/` como archivos con nombre propio, no dentro de
`research.md`/`data-model.md` (que son artefactos de planificación de este comando, no el
producto de la función). Ver el árbol completo en `plan.md` § Project Structure.

**Rationale**:
- FR-023 exige que el documento sea "un artefacto nuevo y adicional" que no reemplace ninguna
  spec individual de `specs/`; sacarlo de `specs/104-.../` a una carpeta de raíz propia evita que
  alguien lo confunda con la documentación de planificación de *esta* spec en particular, ya que
  el documento describe el sistema completo, no solo esta función.
- Ya existe precedente directo en este mismo repositorio: `docs-publicos/` (entregable de
  contenido) vive en la raíz, separado de `specs/<numero>-.../` (artefactos de planificación de la
  spec que lo originó). `srs/` sigue el mismo patrón para mantener consistencia.
- Los tres artefactos intermedios (inventario de backend, inventario de frontend, cruce
  front↔back) sí pertenecen a la ejecución de *esta* spec — son el resultado de las User Stories
  1-3 — por eso viven en `specs/104-.../`, igual que cualquier otro artefacto de ejecución de una
  spec.

**Alternatives considered**:
- Guardar todo (inventarios + SRS final) dentro de `specs/104-.../`: rechazado porque mezclaría un
  documento de alcance "sistema completo" con la carpeta de una spec puntual, dificultando que
  alguien futuro entienda que el SRS sobrevive y se actualiza independientemente del ciclo de vida
  de la spec 104.
- Guardar el SRS final dentro de `docs-publicos/`: rechazado explícitamente — esa carpeta es
  contenido para audiencia externa (`skeilopos.com/docs`) en español neutro comercial; el SRS es
  un artefacto técnico interno en español de Colombia (Decisión 6), con estructura y audiencia
  distintas (ingeniero/arquitecto que necesita trazabilidad hacia código, no un usuario final del
  SaaS).

## Decisión 2 — Estructura de archivos del SRS final dentro de `srs/`

**Decisión**: el documento se divide en un archivo principal `srs/README.md` (Introducción,
Descripción general, Requisitos específicos organizados por módulo/dominio de negocio) y cinco
archivos de apéndice independientes bajo `srs/apendices/`: `a-trazabilidad.md`,
`b-equivalencia-normas.md`, `c-preguntas-abiertas.md`, `d-discrepancias.md`,
`e-cobertura.md` — enlazados desde `README.md`.

**Rationale**: con ~168 endpoints detectados preliminarmente en `pos-backend` (28 módulos de
router bajo `app/api/v1/`) y ~22 módulos de funcionalidad en `pos-heladeria` (bajo
`src/app/modules/`), una matriz de trazabilidad completa (Apéndice A) y la lista de hallazgos
(Apéndice D) tendrán extensión propia considerable; mantenerlos como archivos separados permite
editarlos y revisarlos de forma independiente del cuerpo narrativo del documento, sin que un único
archivo gigante se vuelva impráctico de navegar o de revisar en un diff.

**Alternatives considered**:
- Un solo archivo `srs/README.md` con todo embebido: rechazado por extensión esperada y porque
  dificulta revisar en un diff de PR qué apéndice cambió.
- Un apéndice por módulo de negocio en vez de por tipo (A-E): rechazado porque el spec ya define
  los apéndices por tipo (A-E, FR-019) con contenido transversal a todos los módulos (p. ej. el
  Apéndice A cubre *todos* los endpoints, no solo los de un módulo).

## Decisión 3 — Formato exacto de la etiqueta de evidencia

**Decisión**: toda afirmación lleva exactamente una etiqueta al final de la oración o de la fila
de tabla que la contiene, con esta sintaxis fija:
- `[CÓDIGO: <ruta-relativa-al-repo>:<línea-o-rango>]` — ej. `[CÓDIGO: pos-backend/app/api/v1/orders/router.py:112]`. La ruta siempre empieza por `pos-backend/` o `pos-heladeria/` para no depender de desde qué checkout se lea el documento.
- `[INFERIDO: <motivo breve de la inferencia>]` — ej. `[INFERIDO: no hay test que cubra este
  caso, se deduce del tipo de la columna en el modelo]`.
- `[PREGUNTA]` — remite siempre a una entrada numerada del Apéndice C (`[PREGUNTA → C-07]`).

**Rationale**: FR-014 exige una etiqueta por afirmación "sin excepción"; fijar la sintaxis ahora
(en vez de dejarla implícita) es lo que permite que la Fase 1 (`data-model.md`, `contracts/`)
defina una regla de validación objetiva y muestreable (SC-002: "cero afirmaciones sin etiquetar en
una revisión de muestreo"), y que el Apéndice A pueda generarse por concatenación mecánica de
citas sin reinterpretarlas.

**Alternatives considered**: usar superíndices o notas al pie estilo académico — rechazado porque
Markdown plano no soporta notas al pie de forma portable entre visores (GitHub, editores locales),
y el objetivo es que la cita sea legible inline sin saltar de sección.

## Decisión 4 — Alcance de "demasiado extenso para una sola pasada" (FR-021)

**Decisión**: la unidad de división es el módulo/dominio de negocio tal como lo revela la propia
estructura de código (cada subcarpeta de `pos-backend/app/api/v1/` con su `router.py`, y cada
subcarpeta de `pos-heladeria/src/app/modules/`), no una partición arbitraria por tamaño de
archivo. Si un módulo individual (p. ej. `orders/`, que ya tiene `router.py`, `checkout.py`,
`consolidation.py`, `consumption.py`, `kitchen.py`, `tables_advanced.py`) resulta en sí mismo
extenso, se analiza en sub-pasadas por archivo dentro del mismo módulo, pero el inventario nunca
se publica con un módulo "a medias" sin declararlo explícitamente.

**Rationale**: dividir por módulo de código real (no por conteo de líneas) mantiene la cobertura
verificable: el Apéndice E (FR-022) necesita poder afirmar "X% de los módulos de
`pos-backend/app/api/v1/` cubiertos" con una definición de módulo que coincide exactamente con la
que ya usa el propio repositorio, en vez de una partición inventada solo para este análisis.

**Alternatives considered**: dividir por número fijo de líneas de código — rechazado porque
rompería módulos de negocio a la mitad de forma arbitraria, dificultando que el Apéndice A agrupe
correctamente los hallazgos por dominio.

## Decisión 5 — Mecanismo concreto del punto de parada (FR-020)

**Decisión**: al completar el cruce front↔back (`cruce-front-back.md`, User Story 3), el proceso
termina ese artefacto con una sección final explícita "⏸ Punto de parada — pendiente de
confirmación" que resume cuántos hallazgos se detectaron por categoría (endpoints no consumidos,
contratos distintos, validaciones solo-frontend, roles inconsistentes) y pide confirmación textual
del usuario antes de que cualquier ejecución posterior (`/speckit-tasks`, `/speckit-implement` o
continuación manual) redacte `srs/README.md` o cualquier archivo bajo `srs/apendices/`.

**Rationale**: el spec exige detenerse "de forma verificable" (SC-005); un encabezado fijo y
localizable mecánicamente en `cruce-front-back.md` es lo que permite que `quickstart.md` incluya
un paso de verificación objetivo ("¿existe y está resuelta esta sección antes de que exista algún
archivo bajo `srs/`?"), en vez de depender de que alguien recuerde haber pedido o dado la
confirmación.

**Alternatives considered**: usar un archivo de estado separado (`.srs-checkpoint`) — rechazado
por añadir un artefacto más que mantener sincronizado sin beneficio sobre tener la sección dentro
del propio documento que un humano ya tiene que leer para confirmar.

## Decisión 6 — Idioma del entregable

**Decisión**: el SRS completo (`srs/README.md` y sus apéndices) se escribe en español de
Colombia, igual que el resto de los artefactos de esta fase del proyecto (research/data-
model/quickstart/plan y los propios inventarios). No aplica aquí la excepción de "español neutro"
que sí rige para `docs-publicos/` (esa excepción es específica del FR-009 de la spec 104 anterior,
descartada por esta misma spec), porque la audiencia del SRS es interna (ingeniería, arquitectura,
Product Owner), no un usuario final del SaaS.

**Rationale**: aplica directamente el Principio XIII de la constitución sin necesidad de
excepción — es la primera vez en esta spec que corresponde la regla general sin matices, a
diferencia de la spec anterior en este mismo número.

**Alternatives considered**: inglés técnico (común en documentos IEEE 830 de referencia) —
rechazado porque el resto del proyecto, su código de negocio y su equipo operan en español de
Colombia; mezclar idiomas en el documento interno de mayor alcance del proyecto iría contra el
Principio XIII sin que exista ninguna razón de audiencia externa que lo justifique aquí.

## Decisión 7 — Uso de `docs-publicos/` y de las specs existentes como apoyo, nunca como fuente

**Decisión**: la taxonomía de módulos usada en `docs-publicos/` (6 módulos de negocio) y el
contenido de las specs ya implementadas en `specs/` se consultan como contexto de orientación
inicial al empezar cada inventario, pero ninguna afirmación del SRS puede citar una spec o
`docs-publicos/` como su única evidencia — toda afirmación debe verificarse contra el código real
de `pos-backend`/`pos-heladeria` en el momento del análisis antes de registrarse con etiqueta
`[CÓDIGO]` o `[INFERIDO]`.

**Rationale**: esto ya está implícito en los Edge Cases y Asunciones del spec ("prevalece el
comportamiento real observado en el código"), pero conviene fijarlo aquí como regla operativa de
la Fase 0 para que la ejecución de las User Stories 1-2 no derive en transcribir specs antiguas en
vez de inventariar código.

**Alternatives considered**: prohibir completamente leer `docs-publicos/` y `specs/` durante el
análisis — rechazado porque ignorar ese contexto haría más lento identificar qué módulos de
negocio existen y aumentaría el riesgo de pasar por alto un dominio completo al empezar desde
cero.

## Resumen de alcance verificado (insumo para Technical Context del plan)

Medido por lectura directa de ambos repositorios el 2026-10-08, solo para dimensionar el esfuerzo
(no es contenido del SRS en sí, que debe re-verificarse durante la ejecución de las User Stories):

| Repositorio | Indicador | Valor observado |
|---|---|---|
| `pos-backend` | Módulos de router bajo `app/api/v1/` | 30 (`admin`, `audit`, `auth`, `bootstrap`, `business_hours`, `cart`, `cash`, `catalog`, `categories`, `health`, `inventory`, `invitations`, `invoices`, `menu`, `notifications`, `orders`, `plan`, `presentations`, `products`, `promotions`, `realtime`, `reports`, `sales`, `super_admin`, `table_sessions`, `tables`, `tenant`, `unit_measures`, `uploads`, `users`) |
| `pos-backend` | Decoradores `@router.(get\|post\|put\|patch\|delete)` | ~168 |
| `pos-backend` | Archivos de modelo bajo `app/models/` | 40 |
| `pos-backend` | Archivos de characterization tests | 134 |
| `pos-heladeria` | Módulos de feature bajo `src/app/modules/` | 20 (`account`, `auth`, `cash-register`, `categories`, `dashboard`, `inventory`, `option-groups`, `orders`, `plan`, `presentations`, `products`, `promotions`, `reports`, `sales`, `settings`, `super-admin`, `suppliers`, `tables`, `unit-measures`, `users`) |
| `pos-heladeria` | Archivos de definición de rutas | 3 (`app.routes.ts`, `modules/super-admin/routes.ts`, `modules/dashboard/routes.ts`) |
| `pos-heladeria` | Archivos `*.spec.ts` | 121 |

Stack verificado: `pos-backend` → Python 3.12, FastAPI 0.136.3, SQLAlchemy 2.0.50, Pydantic 2.13,
PostgreSQL (vía `psycopg`/`psycopg2`), Alembic 1.18.4. `pos-heladeria` → Angular 21.1, TypeScript
5.9.2, `@tanstack/angular-query-experimental`.
