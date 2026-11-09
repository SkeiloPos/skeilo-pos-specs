# Implementation Plan: Fusión de las hojas Productos y Presentaciones/precios en el Excel de la carta

**Branch**: `155-fusion-hojas-productos-precios-excel` | **Date**: 2026-11-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/155-fusion-hojas-productos-precios-excel/spec.md`

## Summary

Evolución puntual de la spec 143 (export/import masivo de la carta vía Excel): las hojas
"Productos" y "Presentaciones y precios" se fusionan en una sola hoja "Productos y precios" (una
fila por presentación, con los datos de producto repetidos en cada fila de ese producto), reduciendo
el archivo de 4 hojas a 3 ("Productos y precios", "Receta", "Adiciones", en ese nuevo orden de
procesamiento). No se toca ningún modelo de datos ni dependencia (`products.code` y
`product_import_jobs`, ambas de la 143, se reutilizan sin cambios) — el trabajo vive enteramente en
`app/api/v1/products/{export.py,import_.py,schemas.py}`: una plantilla de 16 columnas en vez de dos
plantillas separadas, una validación de consistencia entre filas del mismo código de producto antes
de aplicar cualquiera (FR-005), presentación y precio obligatorios en toda fila (FR-004), y el
rechazo del formato anterior de 4 hojas como efecto natural (no un caso especial) del mismo mecanismo
de validación de estructura que ya existía.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`) — sin cambios respecto a la 143.

**Primary Dependencies**: FastAPI + SQLAlchemy 2.0 + `openpyxl` + Celery + Redis (todas ya en uso
por la 143 para este mismo flujo) — Angular 21 + `startVisibleInterval` ya existente.
**Ninguna dependencia nueva** (Principio IX): esta spec no agrega infraestructura, solo cambia el
contenido/validación de un archivo que ya se genera y consume con las mismas herramientas.

**Storage**: PostgreSQL 16, un esquema por tenant. **Sin migración nueva** (research.md D6): se
reutilizan sin cambios `products.code` y `product_import_jobs`, ambas ya creadas por la migración de
la spec 143. El único efecto sobre datos ya persistidos es de contenido, no de esquema: el valor de
texto libre `product_import_jobs.errors[].hoja` pasa a poder ser "Productos y precios" en vez de
"Productos"/"Presentaciones y precios" para los jobs que corran después de este despliegue.

**Testing**: `pos-backend` — mismo script autoejecutable `app/scripts/test_products_bulk_excel.py`
de la 143, extendido con los casos propios de esta spec (ver `quickstart.md`), + regresión de
`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`. No hay ningún
characterization test sobre export/import de la carta que esta spec reabra (Principio III no
aplica). `pos-heladeria` — `npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'`
(Vitest).

**Target Platform**: servidor Linux (API) + worker Celery (mismo proceso/infra ya usado por la 143)
+ SPA Angular en navegador.

**Project Type**: aplicación web existente de dos repositorios, ambos en producción — sin cambios
respecto a la 143.

**Performance Goals**: sin objetivo propio, sin cambio respecto a la 143 (SC-001/SC-002 de esta
spec son de experiencia de edición, no de throughput; el volumen de filas por archivo no cambia, una
fila sigue siendo una presentación).

**Constraints**: cada fila de import sigue haciendo su propio commit independiente (FR-009, hereda
el criterio de la 143) — con una diferencia nueva: antes de aplicar cualquier fila de la hoja
fusionada, se pre-escanea la hoja completa para detectar inconsistencias entre filas del mismo
código (FR-005, research.md D2); ese pre-escaneo es de solo lectura (no hace ningún commit) y corre
antes del primer commit de la hoja, para poder garantizar que un grupo inconsistente nunca aplica
ninguna de sus filas. Las hojas se procesan en el orden Productos y precios → Receta → Adiciones
(FR-007), una hoja menos que la 143.

**Scale/Scope**: 0 columnas/tablas nuevas; 0 endpoints nuevos (los 5 de la 143 se reutilizan sin
cambios de ruta/método — solo cambia qué valida/genera `export.py`/`import_.py` internamente); 0
tareas Celery nuevas (`import_products_task` se reutiliza, ahora invocando el procesamiento de 3
hojas en vez de 4). En frontend: ningún componente ni endpoint nuevo — el modal de progreso y el
resumen final ya existentes de la 143 muestran 3 hojas en vez de 4 sin cambio de contrato
(`ProductImportJobResponse` no cambia de forma).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/155-fusion-hojas-productos-precios-excel/spec.md`, ya clarificado (3 preguntas resueltas) |
| II. Comportamiento existente protegido | PASS, con cambio explícito registrado en el propio spec (Clarifications): el archivo de 4 hojas de la spec 143 deja de ser válido para reimportar (corte directo, decisión de negocio ya tomada y documentada en el Input/Clarifications del spec, con fecha 2026-11-09) — no requiere una entrada adicional en `registro-de-anomalias.md` porque el propio spec de evolución funcional ya es el registro de esa decisión (sigue el mismo patrón que la 143 documentó para su propio alcance) |
| III. Characterization tests | PASS, no aplica — no existe ningún test `"CONGELA comportamiento actual:"` sobre export/import de la carta (la 143 tampoco lo generó, por ser funcionalidad enteramente nueva en su momento) |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — la fusión de hojas, la validación de consistencia entre filas (FR-005) y la obligatoriedad de presentación+precio (FR-004) son comportamiento nuevo definido explícitamente por este spec |
| V. Sin refactors oportunistas | PASS — se modifican únicamente `export.py`, `import_.py` y `schemas.py` dentro de `app/api/v1/products/`; no se toca `ProductService`, `catalog/service.py`, `router.py` (salvo lo estrictamente necesario para los nombres de hoja en mensajes, si aplica) ni ningún otro módulo sin relación funcional con esta spec. El rechazo del formato anterior reutiliza el mecanismo de validación de estructura ya existente en vez de construir uno dedicado (research.md D5) |
| VI. Evolución incremental | PASS — cero piezas de modelo de datos nuevas; el cambio se acota enteramente a la plantilla de columnas y a la lógica de validación/aplicación de una hoja. No requiere Complexity Tracking |
| VII. Datos históricos | PASS — ninguna factura ni orden se toca; el import solo crea/actualiza catálogo, igual que la 143 |
| VIII. Evolución del modelo de datos | PASS, no aplica — ver `data-model.md`: sin columnas, tablas ni migraciones nuevas (research.md D6) |
| IX. Dependencias nuevas | PASS — cero, se reutiliza exactamente la infraestructura ya validada por la 143 |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script dedicado extendido con los casos propios de esta spec + specs Vitest de `products` |
| XI. Negocio vs técnico | PASS — las decisiones de negocio (qué hacer ante inconsistencia, que toda fila exija presentación+precio, corte directo de formato) ya están en el spec (Clarifications); este plan solo decide el *cómo* (pre-escaneo de consistencia antes de aplicar, reaplicar el producto por fila dentro de un grupo consistente, nombres de columna para evitar colisión de "Activo" — research.md D1/D2/D3) |
| XII. Trazabilidad | PASS — necesidad (fricción reportada por el usuario al navegar dos hojas) → spec 155 → este plan → `tasks.md` → implementación → script de verificación/specs Angular, encadenado además a la spec 143 de la que esta evoluciona |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `feat/155-fusion-hojas-productos-precios-excel` en `pos-backend` y en `pos-heladeria`, desde la rama actual |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` confirma que no se introduce
ninguna pieza de modelo de datos ni dependencia adicional respecto a lo evaluado arriba;
`contracts/api.md` confirma que no se agrega ni elimina ningún endpoint.

## Project Structure

### Documentation (this feature)

```text
specs/155-fusion-hojas-productos-precios-excel/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api.md
└── tasks.md              # /speckit-tasks, no este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/api/v1/products/
│   ├── export.py       # build_products_excel(): 3 hojas (Productos y precios, Receta,
│   │                    #   Adiciones) en vez de 4; "Productos y precios" combina las
│   │                    #   columnas de producto y de variante en una sola fila por
│   │                    #   presentación (research.md D1)
│   ├── import_.py       # validar_estructura contra las 3 hojas nuevas (efecto natural:
│   │                    #   rechaza el formato de 4 hojas, research.md D5);
│   │                    #   validar_y_aplicar_fila_producto + _presentacion se
│   │                    #   fusionan en una sola función por fila de "Productos y
│   │                    #   precios"; nueva pasada de pre-escaneo de consistencia por
│   │                    #   código antes de aplicar cualquier fila de esa hoja
│   │                    #   (research.md D2/D3); _ORDEN_HOJAS pasa a 3 elementos
│   └── schemas.py       # PRODUCT_TEMPLATE_HEADERS + VARIANT_TEMPLATE_HEADERS se
│                         #   fusionan en PRODUCT_AND_VARIANT_TEMPLATE_HEADERS (16
│                         #   columnas, "Activo de la presentación" para evitar la
│                         #   colisión con "Activo" de producto, research.md D1);
│                         #   PRODUCT_IMPORT_SHEETS pasa a 3 claves
└── app/scripts/
    └── test_products_bulk_excel.py   # casos nuevos de esta spec (quickstart.md) +
                                        #   casos heredados de la 143 que no cambian

../pos-heladeria/
└── src/app/modules/products/
    └── components/
        └── product-import-modal.component.ts   # resumen final/plantilla de ayuda en
                                                   #   pantalla referencian 3 hojas en
                                                   #   vez de 4 (sin cambio de contrato
                                                   #   con el backend)
```

**Structure Decision**: se continúa extendiendo el mismo submódulo `app/api/v1/products/`
(`export.py`/`import_.py`/`schemas.py`) que ya creó la spec 143, sin crear ningún archivo nuevo —
mismo criterio que esa spec ya aplicó al extender `products` en vez de fragmentar el dominio
(Principio V). No hay cambios de estructura de carpetas ni de módulos en ninguno de los dos
repositorios.

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba.*
