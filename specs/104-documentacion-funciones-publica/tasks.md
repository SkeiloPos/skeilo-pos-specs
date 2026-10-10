---

description: "Task list for the reverse-engineered SRS (IEEE 830) of SkeiloPOS"
---

# Tasks: SRS por ingeniería inversa de SkeiloPOS (IEEE 830)

**Input**: Design documents from `/specs/104-documentacion-funciones-publica/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (todos presentes y completos)

**Tests**: no se generan tareas de test — esta función no produce software, no hay tests automatizados de contenido que escribir (ver plan.md § Testing: la verificación son los 7 pasos de `quickstart.md`, cubiertos en la Fase de Polish y en la tarea de apertura de la Fase 6).

**Organización**: las tareas se agrupan por User Story (US1-US4, spec.md). Dentro de US1-US3, el trabajo se subdivide por grupo de módulos de código real — la unidad de división fijada en la Decisión 4 de `research.md` — para que ninguna tarea obligue a analizar los 30 módulos de `pos-backend` o los 20 de `pos-heladeria` de una sola vez. Los grupos no son una taxonomía de negocio nueva; son lotes de los propios nombres de carpeta de `pos-backend/app/api/v1/` y `pos-heladeria/src/app/modules/` verificados por lectura directa el 2026-10-08:

- **Backend G1 — Identidad y acceso**: `admin`, `auth`, `bootstrap`, `invitations`, `super_admin`, `tenant`, `users`
- **Backend G2 — Catálogo**: `catalog`, `categories`, `products`, `unit_measures`, `menu`
- **Backend G3 — Presentaciones, promociones e inventario**: `presentations`, `promotions`, `inventory`
- **Backend G4 — Pedidos y mesas**: `orders`, `table_sessions`, `tables`, `cart`, `business_hours`
- **Backend G5 — Caja, ventas y facturación**: `cash`, `sales`, `invoices`, `reports`, `audit`, `plan`
- **Backend G6 — Infraestructura técnica**: `health`, `notifications`, `realtime`, `uploads`

- **Frontend F1 — Identidad y cuenta**: `account`, `auth`, `super-admin`, `users`
- **Frontend F2 — Catálogo**: `categories`, `products`, `unit-measures`, `option-groups`, `suppliers`, `inventory`
- **Frontend F3 — Presentaciones y promociones**: `presentations`, `promotions`
- **Frontend F4 — Pedidos y mesas**: `orders`, `tables`
- **Frontend F5 — Caja, ventas y reportes**: `cash-register`, `sales`, `reports`
- **Frontend F6 — Panel, plan y ajustes**: `dashboard`, `plan`, `settings`

**IMPORTANTE — regla de evidencia (no-excepción)**: toda tarea que redacte una afirmación sobre el comportamiento del sistema debe etiquetarla con `[CÓDIGO: ruta:línea]`, `[INFERIDO: motivo]` o `[PREGUNTA → C-xx]`, sintaxis exacta de `contracts/formato-etiqueta-evidencia.md` (FR-014). Ninguna tarea de este archivo autoriza inventar una métrica, convertir un defecto en requisito, ni citar una spec interna o `docs-publicos/` como única evidencia (research.md Decisión 7) — siempre se verifica contra el código real de `pos-backend`/`pos-heladeria` en el momento de ejecutar la tarea. Todo el análisis es de solo lectura (FR-024): ninguna tarea ejecuta, construye ni modifica archivos de `pos-backend` ni `pos-heladeria`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias)
- **[Story]**: User Story a la que pertenece (US1-US4)

## Path Conventions

Esta función no produce software (plan.md § Project Structure): no hay `src/` ni `tests/`. Las rutas de salida son archivos Markdown:
- Artefactos de trabajo (Fases US1-US3): `specs/104-documentacion-funciones-publica/{inventario-backend.md, inventario-frontend.md, cruce-front-back.md}`
- Entregable final (Fase US4): `srs/README.md` y `srs/apendices/*.md` en la raíz de `pos-specs`
- Fuente leída (nunca modificada): `../pos-backend/` y `../pos-heladeria/` (repos hermanos)

---

## Phase 1: Setup

**Purpose**: confirmar que el entorno de análisis está disponible y que el alcance medido en `research.md` sigue vigente antes de empezar a escribir cualquier artefacto.

- [X] T001 Confirmar que `../pos-backend` y `../pos-heladeria` existen como repos hermanos de `pos-specs`, clonados y legibles; registrar la rama/commit exacto (`git rev-parse HEAD` en cada uno) y la fecha de este checkout — ese dato alimentará la sección de Referencias de `srs/README.md` en la Fase 6 (Asunciones del spec). **Resultado**: `pos-backend` rama `develop` commit `7a356c920dedf4318cc3439d15930869f0a22948`; `pos-heladeria` rama `develop` commit `10794064d9eab27c0cb08a766b2d3fca6eced832`; checkout verificado el 2026-10-08.
- [X] T002 [P] Re-verificar por lectura directa (`ls pos-backend/app/api/v1/`, `ls pos-heladeria/src/app/modules/`) que los módulos listados en la tabla "Resumen de alcance verificado" de `research.md` siguen existiendo sin cambios; si hay un módulo nuevo o eliminado desde el 2026-10-08, anotarlo para incluirlo (o declarar su ausencia) en los grupos de este archivo antes de continuar. **Resultado**: sin cambios — los 30 módulos de `pos-backend/app/api/v1/` y los 20 de `pos-heladeria/src/app/modules/` coinciden exactamente con `research.md`.

**Checkpoint**: alcance confirmado, listo para crear los artefactos de trabajo.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: crear el esqueleto de los tres artefactos de trabajo con la estructura fija que las User Stories 1-3 van a llenar, para que ninguna sección obligatoria quede implícita.

**⚠️ CRITICAL**: ninguna tarea de US1-US3 puede empezar a escribir contenido hasta que su archivo de destino exista con esta estructura.

- [X] T003 [P] Crear `specs/104-documentacion-funciones-publica/inventario-backend.md` con encabezado y secciones vacías: Stack verificado; Endpoints y reglas de negocio (una subsección por cada grupo backend G1-G6 de este archivo); Modelo de datos; Autenticación, autorización y multi-tenant; Integraciones externas; Configuración
- [X] T004 [P] Crear `specs/104-documentacion-funciones-publica/inventario-frontend.md` con encabezado y secciones vacías: Stack verificado; Rutas/pantallas (una subsección por cada grupo frontend F1-F6 de este archivo); Gestión de estado y sesión
- [X] T005 [P] Crear `specs/104-documentacion-funciones-publica/cruce-front-back.md` con encabezado y secciones vacías: Tabla de correspondencia (una subsección por cada grupo backend G1-G6); Hallazgos (`H-xx`, plantilla de `contracts/plantilla-hallazgo.md`); sección final fija "⏸ Punto de parada — pendiente de confirmación" (Decisión 5 de `research.md`), dejada sin resolver hasta que la Fase 5 la complete

**Checkpoint**: los tres artefactos existen con su estructura completa; empieza el trabajo de las User Stories.

---

## Phase 3: User Story 1 - Inventario verificable del backend (Priority: P1) 🎯 MVP

**Goal**: producir `inventario-backend.md` con el 100% de los endpoints de `pos-backend`, su modelo de datos, sus reglas de negocio, su mecanismo de auth/multi-tenant, sus integraciones y su configuración, cada afirmación con etiqueta de evidencia.

**Independent Test**: entregar únicamente `inventario-backend.md` a alguien ajeno al análisis; para cualquier endpoint elegido al azar debe poder ubicar la cita de código o la inferencia que respalda cada afirmación (spec.md US1).

### Implementation for User Story 1

- [X] T006 [US1] Documentar el stack verificado de `pos-backend` (Python, FastAPI, SQLAlchemy, Pydantic, PostgreSQL, Alembic, con sus versiones exactas) en `inventario-backend.md` § Stack, citando `pos-backend/pyproject.toml` o `pos-backend/requirements*.txt` [CÓDIGO]
- [X] T007 [US1] Inventariar en `inventario-backend.md` § Endpoints, grupo G1 (`admin`, `auth`, `bootstrap`, `invitations`, `super_admin`, `tenant`, `users`): cada endpoint con método, ruta, esquema de entrada/salida, autenticación requerida, roles/permisos y códigos de error (FR-001), citando `pos-backend/app/api/v1/<módulo>/router.py` [CÓDIGO]; incluir en la misma subsección las reglas de negocio de la capa de servicio de estos módulos (validaciones, cálculos, transiciones de estado, efectos secundarios — FR-003), usando los characterization tests de cada módulo como evidencia del comportamiento intencionado cuando exista (FR-007)
- [X] T008 [US1] Repetir T007 para el grupo G2 (`catalog`, `categories`, `products`, `unit_measures`, `menu`)
- [X] T009 [US1] Repetir T007 para el grupo G3 (`presentations`, `promotions`, `inventory`)
- [X] T010 [US1] Repetir T007 para el grupo G4 (`orders`, `table_sessions`, `tables`, `cart`, `business_hours`)
- [X] T011 [US1] Repetir T007 para el grupo G5 (`cash`, `sales`, `invoices`, `reports`, `audit`, `plan`)
- [X] T012 [US1] Repetir T007 para el grupo G6 (`health`, `notifications`, `realtime`, `uploads`)
- [X] T013 [US1] Documentar en `inventario-backend.md` § Modelo de datos cada entidad de `pos-backend/app/models/` (atributos, tipos, nulabilidad, defaults, relaciones/FK, restricciones de unicidad, checks, enums) y las migraciones de `pos-backend/alembic/versions/` que aporten contexto no evidente en el modelo actual (FR-002), siguiendo los campos de la entidad "Entidad de datos" de `data-model.md` [CÓDIGO]
- [X] T014 [US1] Documentar en `inventario-backend.md` § Autenticación, autorización y multi-tenant el mecanismo completo (esquema de token/sesión, expiración, dependencias `Depends(...)` de auth, cómo se aísla cada tenant) observado en `pos-backend/app/core/` y en los módulos `auth`/`bootstrap`/`tenant` (FR-004) [CÓDIGO]
- [X] T015 [US1] Documentar en `inventario-backend.md` § Integraciones externas cada integración con evidencia verificable en el código (APIs externas, colas, correo, pagos, almacenamiento/R2, webhooks — FR-005); si una integración sospechada no tiene evidencia verificable, registrarla como `[PREGUNTA → C-xx]` en vez de asumirla
- [X] T016 [US1] Documentar en `inventario-backend.md` § Configuración las variables de entorno (`pos-backend/.env.example`, nunca valores reales de `.env`), `pos-backend/Dockerfile`, `pos-backend/docker-compose*.yml` y `pos-backend/.github/workflows/` relevantes, y cualquier tarea programada detectada (FR-006), sin exponer ningún secreto/credencial/token real

**Checkpoint**: `inventario-backend.md` completo y verificable de forma independiente — User Story 1 entregada.

---

## Phase 4: User Story 2 - Inventario verificable del frontend (Priority: P2)

**Goal**: producir `inventario-frontend.md` con el 100% de las rutas/pantallas de `pos-heladeria`, su guarda de rol, sus acciones/validaciones/estados, sus llamadas a la API y su manejo de errores.

**Independent Test**: entregar únicamente `inventario-frontend.md` a alguien ajeno al análisis; para cualquier pantalla elegida al azar debe poder identificar su rol, su(s) endpoint(s) consumido(s) y la cita de código que respalda cada afirmación (spec.md US2).

**Nota de dependencia**: esta fase solo depende de la Fase 2 (Foundational); puede ejecutarse en paralelo con la Fase 3 (US1) o justo después, según disponibilidad (spec.md US2 "Why this priority").

### Implementation for User Story 2

- [X] T017 [US2] Documentar el stack verificado de `pos-heladeria` (Angular, TypeScript, `@tanstack/angular-query-experimental`, con sus versiones exactas) en `inventario-frontend.md` § Stack, citando `pos-heladeria/package.json` [CÓDIGO]
- [X] T018 [US2] Inventariar en `inventario-frontend.md` § Rutas/pantallas, grupo F1 (`account`, `auth`, `super-admin`, `users`): cada ruta con su path exacto, guarda de navegación por rol (`canActivate` o su ausencia explícita), acciones de usuario y formularios, validaciones de cliente (`Validators.*`/custom), estados de vacío/carga/error cuando existan, y cada llamada a la API (cliente HTTP + endpoint exacto) con su manejo de errores observado (FR-008, FR-009, FR-010), citando `pos-heladeria/src/app/modules/<módulo>/` y el archivo de rutas correspondiente (`app.routes.ts` o el `routes.ts` propio del módulo) [CÓDIGO]; nunca inventar una validación o un estado que no esté literalmente en el código
- [X] T019 [US2] Repetir T018 para el grupo F2 (`categories`, `products`, `unit-measures`, `option-groups`, `suppliers`, `inventory`)
- [X] T020 [US2] Repetir T018 para el grupo F3 (`presentations`, `promotions`)
- [X] T021 [US2] Repetir T018 para el grupo F4 (`orders`, `tables`)
- [X] T022 [US2] Repetir T018 para el grupo F5 (`cash-register`, `sales`, `reports`)
- [X] T023 [US2] Repetir T018 para el grupo F6 (`dashboard`, `plan`, `settings`)
- [X] T024 [US2] Documentar en `inventario-frontend.md` § Gestión de estado y sesión el mecanismo observado (store/servicio de estado, manejo del token de sesión, expiración/logout automático) en `pos-heladeria/src/app/core/` o equivalente (FR-011) [CÓDIGO]

**Checkpoint**: `inventario-frontend.md` completo y verificable de forma independiente — User Story 2 entregada. Con esto, US1 y US2 juntas habilitan la User Story 3.

---

## Phase 5: User Story 3 - Cruce front↔back y hallazgos críticos (Priority: P3)

**Goal**: producir `cruce-front-back.md` con la tabla de correspondencia completa (100% de los endpoints marcados consumido/no consumido/parcial) y los hallazgos de discrepancia, terminando en el punto de parada obligatorio que exige confirmación explícita del usuario antes de redactar el SRS completo.

**Independent Test**: con los inventarios de US1 y US2 ya completos, entregar únicamente la tabla de correspondencia y la lista de hallazgos; un revisor debe poder confirmar, tomando tres hallazgos al azar, que cada uno señala una discrepancia real entre el código del backend y el del frontend (spec.md US3).

**⚠️ Dependencia dura**: ninguna tarea de esta fase puede empezar hasta que **todas** las tareas de la Fase 3 (US1) y de la Fase 4 (US2) estén completas — un endpoint de cualquier grupo backend puede ser consumido por una pantalla de *cualquier* grupo frontend, no solo el de nombre equivalente.

### Implementation for User Story 3

- [X] T025 [US3] En `cruce-front-back.md` § Tabla de correspondencia, grupo backend G1 (`admin`, `auth`, `bootstrap`, `invitations`, `super_admin`, `tenant`, `users`): para cada endpoint de `inventario-backend.md` de este grupo, buscar en la totalidad de `inventario-frontend.md` (los seis grupos F1-F6) si existe una llamada que lo consuma; marcar cada endpoint como consumido/no consumido/parcial (FR-012); registrar como Hallazgo (`H-xx`, plantilla de `contracts/plantilla-hallazgo.md`) cada endpoint no consumido, cada llamada del frontend sin endpoint correspondiente o con contrato distinto, cada validación presente solo en el frontend, cada validación inconsistente entre ambos lados, y cada rol/permiso aplicado en un lado pero no en el otro (FR-013)
- [X] T026 [US3] Repetir T025 para el grupo backend G2 (`catalog`, `categories`, `products`, `unit_measures`, `menu`)
- [X] T027 [US3] Repetir T025 para el grupo backend G3 (`presentations`, `promotions`, `inventory`)
- [X] T028 [US3] Repetir T025 para el grupo backend G4 (`orders`, `table_sessions`, `tables`, `cart`, `business_hours`)
- [X] T029 [US3] Repetir T025 para el grupo backend G5 (`cash`, `sales`, `invoices`, `reports`, `audit`, `plan`)
- [X] T030 [US3] Repetir T025 para el grupo backend G6 (`health`, `notifications`, `realtime`, `uploads`)
- [X] T031 [US3] Tras completar T025-T030: confirmar que el 100% de los endpoints de `inventario-backend.md` aparece marcado en la tabla de correspondencia; redactar en `cruce-front-back.md` la sección final fija "⏸ Punto de parada — pendiente de confirmación" con el resumen de hallazgos por categoría (Decisión 5 de `research.md`, FR-020, SC-005); presentar ese resumen al usuario y **detener el proceso** — ninguna tarea de la Fase 6 puede ejecutarse hasta recibir confirmación textual explícita del usuario sobre este resultado

**Checkpoint**: `cruce-front-back.md` completo; el proceso está detenido en el punto de parada. **No continuar a la Fase 6 sin la confirmación explícita del usuario.**

---

## Phase 6: User Story 4 - Redacción del SRS completo con trazabilidad (Priority: P4)

**Goal**: redactar el SRS final (`srs/README.md` + `srs/apendices/`) en formato IEEE 830 con equivalencias 29148, organizado por módulo/dominio de negocio, con cada requisito trazado y los cinco apéndices completos.

**Independent Test**: entregar el SRS completo a alguien ajeno al análisis; debe poder tomar cualquier requisito al azar y seguir su trazabilidad hasta el endpoint/pantalla/entidad citado, confirmando que su etiqueta de evidencia es correcta (spec.md US4).

**⚠️ Dependencia dura**: la Fase 6 completa depende de que T031 (punto de parada) esté resuelto **y** de que el usuario haya dado su confirmación explícita (FR-020). T032 es el gate que verifica esa condición antes de crear ningún archivo bajo `srs/`.

### Implementation for User Story 4

- [X] T032 [US4] Confirmar que T031 está resuelto, que el usuario dio su confirmación explícita sobre el resultado de la Fase 5, y que **no existe todavía ningún archivo** bajo `srs/` en la raíz de `pos-specs` (quickstart.md paso 3); solo entonces crear `srs/README.md` y la carpeta `srs/apendices/` vacíos, listos para llenarse
- [X] T033 [US4] Redactar en `srs/README.md` § 1 Introducción: propósito, alcance, definiciones/acrónimos, referencias (specs internas consultadas, rama/commit exacto de `pos-backend` y `pos-heladeria` registrado en T001, fecha del análisis), visión general del documento (contrato: `contracts/estructura-srs-ieee830.md` fila 1)
- [X] T034 [US4] Redactar en `srs/README.md` § 2 Descripción general: perspectiva del producto, funciones principales por módulo, características de los roles de usuario, restricciones generales, supuestos y dependencias, incluido el diagrama de contexto del producto como bloque Mermaid embebido (Asunciones del spec; contrato fila 2)
- [X] T035 [US4] Redactar en `srs/README.md` § 3.1 Requisitos de interfaces externas: interfaces de usuario (remisión a `inventario-frontend.md`), interfaces de software (remisión a `inventario-backend.md`), interfaces de comunicación (HTTP, WebSocket si hay evidencia en el módulo `realtime`) (contrato fila 3.1)
- [X] T036 [US4] Redactar en `srs/README.md` § 3.2 Requisitos funcionales los RF del grupo backend G1 (`admin`, `auth`, `bootstrap`, `invitations`, `super_admin`, `tenant`, `users`), usando `contracts/plantilla-requisito.md` con ID `RF-<módulo>-<secuencial>` (el `<módulo>` coincide con el nombre usado en `inventario-backend.md`), basados en los endpoints y reglas de negocio de T007 y en los hallazgos de T025 — ningún Hallazgo se reescribe como RF (FR-016)
- [X] T037 [US4] Repetir T036 para el grupo backend G2 (basado en T008/T026)
- [X] T038 [US4] Repetir T036 para el grupo backend G3 (basado en T009/T027)
- [X] T039 [US4] Repetir T036 para el grupo backend G4 (basado en T010/T028)
- [X] T040 [US4] Repetir T036 para el grupo backend G5 (basado en T011/T029)
- [X] T041 [US4] Repetir T036 para el grupo backend G6 (basado en T012/T030)
- [X] T042 [US4] Redactar en `srs/README.md` § 3.3 Requisitos de rendimiento solo las afirmaciones con evidencia verificable en el código (índices, paginación, timeouts, caché observados en T007-T016); donde no haya evidencia, declarar explícitamente "sin evidencia verificable de código; ver preguntas abiertas" y registrar la pregunta en el Apéndice C en vez de asumir un valor (FR-015, contrato fila 3.3)
- [X] T043 [US4] Redactar en `srs/README.md` § 3.4 Restricciones de diseño verificadas (versiones de framework, convenciones de arquitectura multi-tenant de T014, patrones repetidos entre módulos) (contrato fila 3.4)
- [X] T044 [US4] Redactar en `srs/README.md` § 3.5 Atributos del sistema los RNF de seguridad, fiabilidad, disponibilidad, mantenibilidad y portabilidad con evidencia verificable (usando la misma plantilla de requisito), derivados de T014-T016 y de los hallazgos de seguridad detectados en la Fase 5; ningún Hallazgo se reescribe como RNF (FR-016, contrato fila 3.5)
- [X] T045 [US4] Redactar en `srs/README.md` § 3.6 Requisitos de datos: el diagrama entidad-relación completo como bloque Mermaid embebido y el detalle por entidad, por remisión a `inventario-backend.md` § Modelo de datos (T013) (contrato fila 3.6)
- [X] T046 [US4] Redactar `srs/apendices/a-trazabilidad.md` (Apéndice A): matriz completa RF/RNF ↔ endpoint(s)/pantalla(s)/entidad(es), consolidando T036-T045 y la tabla de correspondencia de T025-T030; todo endpoint marcado consumido/no consumido (contrato fila A)
- [X] T047 [US4] Redactar `srs/apendices/b-equivalencia-normas.md` (Apéndice B): la tabla de equivalencia IEEE 830 ↔ ISO/IEC/IEEE 29148 de `contracts/estructura-srs-ieee830.md`, documentada como parte entregada del SRS (contrato fila B)
- [X] T048 [US4] Redactar `srs/apendices/c-preguntas-abiertas.md` (Apéndice C): consolidar toda referencia `[PREGUNTA → C-xx]` aparecida en `inventario-backend.md`, `inventario-frontend.md`, `cruce-front-back.md` y en `srs/README.md`, cada una con impacto y prioridad; verificar que cada pregunta es genuinamente no determinable desde el código antes de incluirla (SC-006, contrato fila C)
- [X] T049 [US4] Redactar `srs/apendices/d-discrepancias.md` (Apéndice D): consolidar todos los Hallazgos (`H-xx`) de `cruce-front-back.md` con `contracts/plantilla-hallazgo.md`; confirmar que ninguno aparece también redactado como RF/RNF vigente en T036-T044 (FR-016, SC-003, contrato fila D)
- [X] T050 [US4] Redactar `srs/apendices/e-cobertura.md` (Apéndice E): calcular y reportar el porcentaje real de endpoints y de pantallas cubiertos por al menos un requisito documentado (FR-022), y declarar explícitamente cualquier módulo que haya quedado fuera de alcance de este análisis (FR-021, contrato fila E)

**Checkpoint**: `srs/README.md` y los cinco apéndices completos — User Story 4 entregada; el SRS está listo para la verificación final de Polish.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: ejecutar la verificación completa de `quickstart.md` sobre el SRS final ya redactado, y dejar registrada la referencia exacta de lo analizado.

- [X] T051 [P] Ejecutar `quickstart.md` pasos 1-2 sobre `inventario-backend.md` e `inventario-frontend.md`: muestrear tres endpoints y tres pantallas al azar y confirmar que cada cita `[CÓDIGO]` coincide exactamente con el archivo:línea real
- [X] T052 Ejecutar `quickstart.md` paso 4 (SC-002) sobre una muestra de 10 oraciones declarativas tomadas de `srs/README.md` y sus apéndices: confirmar que cada una lleva exactamente una etiqueta con la sintaxis de `contracts/formato-etiqueta-evidencia.md`, y que cada `[PREGUNTA → C-xx]` de la muestra resiste una búsqueda deliberada en el código antes de aceptarse como legítima
- [X] T053 Ejecutar `quickstart.md` paso 5 (SC-003) sobre `srs/README.md` § 3.2/3.5 y `srs/apendices/d-discrepancias.md`: confirmar que ningún Hallazgo del Apéndice D aparece también redactado como capacidad intencionada en la sección de requisitos
- [X] T054 Ejecutar `quickstart.md` paso 6 (SC-001, SC-004) sobre el SRS final: seguir la trazabilidad de un requisito al azar hasta el Apéndice A, y confirmar que el porcentaje de `srs/apendices/e-cobertura.md` es consistente con un conteo manual de 10 filas del Apéndice A
- [X] T055 Ejecutar `quickstart.md` paso 7 (FR-019) comparando el índice real de `srs/README.md` contra `contracts/estructura-srs-ieee830.md`: confirmar coincidencia 1 a 1 y que los cinco apéndices existen como archivos independientes enlazados desde `srs/README.md`
- [X] T056 [P] Ejecutar `quickstart.md` paso 8 (FR-023) sobre `srs/README.md`: confirmar que ningún requisito contradice o sustituye una spec individual existente en `specs/`, y que no se modificó ningún archivo fuera de `srs/` o de esta misma carpeta de spec

**Checkpoint**: las siete verificaciones de `quickstart.md` (SC-001 a SC-006, más FR-023) pasaron sobre el entregable final.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato
- **Foundational (Phase 2)**: depende de Setup — bloquea el inicio de cualquier User Story
- **User Story 1 (Phase 3)**: depende solo de Foundational
- **User Story 2 (Phase 4)**: depende solo de Foundational; puede ejecutarse en paralelo con la Fase 3 o justo después
- **User Story 3 (Phase 5)**: depende de que **todas** las tareas de la Fase 3 y de la Fase 4 estén completas (T006-T024)
- **User Story 4 (Phase 6)**: depende de T031 resuelto **y** de la confirmación explícita del usuario (FR-020) — gate verificado en T032
- **Polish (Phase 7)**: depende de que toda la Fase 6 esté completa (T032-T050); T056 puede ejecutarse en paralelo con T051-T055 (verifica un criterio distinto, FR-023)

### Dentro de cada User Story

- Fase 3: T006 (stack) antes de T007-T016 solo por orden lógico de lectura del archivo, sin dependencia dura; T007-T012 son sucesivos (mismo archivo, distinta subsección); T013-T016 pueden hacerse en cualquier orden entre sí tras T007-T012
- Fase 4: igual patrón que la Fase 3, con T017 primero y T018-T024 sucesivos
- Fase 5: T025-T030 son sucesivos (mismo archivo); T031 depende de que las seis terminen
- Fase 6: T032 es el gate; T033-T035 preceden naturalmente a T036-T050 por orden narrativo del documento, sin dependencia dura entre sí salvo T046 (depende de T036-T045 y de T025-T030), T048 (depende de todas las tareas que puedan haber generado una `[PREGUNTA → C-xx]`) y T049 (depende de T025-T030 y verifica contra T036-T044)

### Parallel Opportunities

- T001 y T002 pueden ejecutarse en paralelo (Setup)
- T003, T004 y T005 pueden ejecutarse en paralelo (Foundational — tres archivos distintos)
- La Fase 3 (US1) y la Fase 4 (US2) pueden ejecutarse en paralelo entre sí una vez completada la Fase 2 (archivos distintos: `inventario-backend.md` vs `inventario-frontend.md`)
- Dentro de T051 (Polish), la muestra de backend y la de frontend pueden verificarse en paralelo

---

## Parallel Example: Setup + Foundational

```bash
# Fase 1 (en paralelo):
Task: "T001 Confirmar repos hermanos y registrar rama/commit exacto"
Task: "T002 Re-verificar lista de módulos contra research.md"

# Fase 2 (en paralelo, tres archivos distintos):
Task: "T003 Crear inventario-backend.md con su estructura"
Task: "T004 Crear inventario-frontend.md con su estructura"
Task: "T005 Crear cruce-front-back.md con su estructura"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Fase 1: Setup
2. Completar Fase 2: Foundational (bloquea todo lo demás)
3. Completar Fase 3: User Story 1 (`inventario-backend.md` completo)
4. **Detenerse y validar**: ejecutar `quickstart.md` pasos 1 y 4 (parcial) sobre el inventario de backend por sí solo
5. Esto ya constituye un entregable útil de forma independiente (spec.md US1 Independent Test)

### Incremental Delivery

1. Setup + Foundational → base lista
2. User Story 1 → inventario de backend verificable de forma independiente
3. User Story 2 (en paralelo o después) → inventario de frontend verificable de forma independiente
4. User Story 3 → cruce front↔back + **punto de parada obligatorio** → esperar confirmación explícita del usuario
5. User Story 4 (solo tras la confirmación) → SRS completo en `srs/`
6. Polish → verificación final de `quickstart.md` (SC-001 a SC-006) sobre el entregable completo

### Punto de parada — nota operativa

La Fase 5 termina en un punto de parada no negociable (FR-020, T031): bajo ninguna circunstancia se ejecutan las tareas de la Fase 6 (T032 en adelante) sin una confirmación textual explícita del usuario sobre el resultado del cruce front↔back. Esto no es una sugerencia de secuenciación sino un requisito funcional del spec.

---

## Notes

- Ninguna tarea de este archivo modifica, ejecuta ni altera código de `pos-backend` ni `pos-heladeria` (FR-024) — todas son lectura + redacción de Markdown
- Toda tarea que redacte una afirmación sobre el sistema debe cerrarla con su etiqueta de evidencia (FR-014); ninguna excepción
- Un comportamiento defectuoso detectado durante cualquier tarea de las Fases 3-5 se registra como Hallazgo (`H-xx`), nunca como requisito (FR-016)
- Si durante una tarea de inventario un módulo resulta demasiado extenso para una sola pasada, se subdivide por archivo dentro del mismo módulo y se declara explícitamente qué quedó fuera (FR-021), sin inventar cobertura total
- Señal orientativa (no umbral estricto) para decidir si un módulo individual es "demasiado
  extenso para una sola pasada" (FR-021): si documentarlo exige citar más de ~15 endpoints
  distintos en una sola subsección, o sus reglas de negocio están repartidas en más de 3
  archivos de servicio/router, se subdivide por archivo dentro del mismo módulo (como ya
  anticipa research.md Decisión 4 para `orders/`), declarando explícitamente qué quedó fuera
  de esa sub-pasada
- Commits de este trabajo en `pos-specs`: solo bajo pedido explícito del usuario, pequeños y por fase/artefacto, en inglés, Conventional Commits, sin atribución de IA (memoria del usuario: convenciones de commit)
