# Feature Specification: SRS por ingeniería inversa de SkeiloPOS (IEEE 830)

**Feature Branch**: `104-documentacion-funciones-publica`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "Producir una Especificación de Requisitos de Software (SRS) siguiendo la estructura de IEEE 830-1998 (con equivalencias a ISO/IEC/IEEE 29148:2018), mediante ingeniería inversa de SkeiloPOS, sistema compuesto por dos repositorios hermanos a pos-specs: backend (`pos-backend`, FastAPI + SQLAlchemy + PostgreSQL) y frontend (`pos-heladeria`, Angular). Regla central: cada afirmación del SRS debe llevar una etiqueta de evidencia ([CÓDIGO]/[INFERIDO]/[PREGUNTA]); prohibido inventar métricas sin evidencia, prohibido convertir un bug en requisito, prohibido describir intenciones de negocio como hechos. Proceso en 4 fases: inventario de backend, inventario de frontend, cruce front↔back (crítico, con punto de parada para validación humana), y redacción del SRS completo siguiendo la estructura IEEE 830 con sus apéndices A-E."

**Nota**: esta función reemplaza por completo el alcance anterior de la spec 104 (que trataba
sobre la documentación pública función por función de SkeiloPOS para `skeilopos.com/docs`); ese
alcance anterior queda descartado para esta spec. El contenido ya entregado bajo ese alcance
previo (carpeta `docs-publicos/` en la raíz del repositorio) permanece en el repositorio como
trabajo ya realizado, pero deja de estar asociado a esta spec.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inventario verificable del backend (Priority: P1)

Un ingeniero de requisitos, arquitecto o desarrollador que se incorpora al proyecto necesita
saber, sin leer todo el código línea por línea, qué expone realmente el backend de SkeiloPOS:
todos sus endpoints, su modelo de datos, sus reglas de negocio, su mecanismo de autenticación y
aislamiento multi-tenant, sus integraciones externas y su configuración — con cada afirmación
señalada según de dónde se obtuvo (código, inferencia, o pregunta abierta), para poder confiar en
el documento sin tener que volver a verificarlo todo por su cuenta.

**Why this priority**: es la base factual de todo lo demás; sin un inventario confiable del
backend no es posible ni cruzarlo contra el frontend (User Story 3) ni redactar un SRS creíble
(User Story 4).

**Independent Test**: se le entrega a alguien que no participó en el análisis únicamente el
inventario del backend (stack, endpoints, modelo de datos, reglas de negocio, auth/autorización,
integraciones, configuración, tests existentes); debe poder ubicar, para cualquier endpoint que
elija al azar, la cita de código o la inferencia que respalda cada afirmación sobre ese endpoint.

**Acceptance Scenarios**:

1. **Given** el código fuente de `pos-backend`, **When** se completa el inventario, **Then**
   todos los endpoints expuestos aparecen listados con método, ruta, esquema de entrada/salida,
   autenticación requerida, roles/permisos y códigos de error, cada uno con su etiqueta de
   evidencia.
2. **Given** una regla de negocio implementada en una capa de servicio, **When** se documenta en
   el inventario, **Then** la afirmación cita el archivo y, cuando aplica, la línea donde esa
   regla vive en el código, en vez de describirse de memoria.
3. **Given** un valor no funcional que no tiene respaldo verificable en el código (por ejemplo, un
   límite de volumen de usuarios), **When** se documenta, **Then** se registra como pregunta
   abierta en vez de como hecho afirmado.

---

### User Story 2 - Inventario verificable del frontend (Priority: P2)

La misma persona de la User Story 1 necesita, además, entender cómo el frontend Angular de
SkeiloPOS (`pos-heladeria`) consume ese backend: qué pantallas existen, qué rol puede ver cada
una, qué acciones y validaciones de cliente ocurren en cada pantalla, a qué endpoint llama cada
una y cómo maneja los errores.

**Why this priority**: depende de poder iterarse en paralelo o justo después de la User Story 1,
pero es condición previa obligatoria de la User Story 3 (el cruce front↔back no puede hacerse sin
ambos inventarios).

**Independent Test**: se le entrega a alguien que no participó en el análisis únicamente el
inventario del frontend; debe poder identificar, para cualquier pantalla que elija, qué rol la
puede ver, qué endpoint(s) consume, y la cita de código que respalda cada afirmación.

**Acceptance Scenarios**:

1. **Given** el código fuente de `pos-heladeria`, **When** se completa el inventario, **Then**
   todas las rutas/pantallas aparecen listadas con su guarda de navegación por rol, cada una con
   su etiqueta de evidencia.
2. **Given** una pantalla con un formulario, **When** se documenta, **Then** se listan sus
   validaciones de cliente y sus estados de vacío/carga/error cuando existen en el código, sin
   inventar ninguno que no esté presente.
3. **Given** una llamada de la pantalla a la API, **When** se documenta, **Then** se cita el
   cliente HTTP y el endpoint exacto consumido, con manejo de errores observado.

---

### User Story 3 - Cruce front↔back y hallazgos críticos (Priority: P3)

La misma persona necesita saber dónde el frontend y el backend **no coinciden**: endpoints que
nadie en el frontend usa, llamadas del frontend a endpoints que no existen o que tienen un
contrato distinto al esperado, validaciones que solo existen en el frontend (riesgo de que el
backend no las repita), validaciones inconsistentes entre ambos lados, y roles/permisos aplicados
de un lado pero no del otro — antes de seguir adelante con la redacción del documento completo.

**Why this priority**: es el paso de mayor riesgo y mayor valor de todo el ejercicio (detecta
código muerto y brechas de seguridad reales), y el spec exige detenerse aquí y esperar
confirmación humana antes de continuar a la User Story 4.

**Independent Test**: con los inventarios de las User Stories 1 y 2 ya completos, se entrega
únicamente la tabla de correspondencia y la lista de hallazgos; un revisor debe poder confirmar,
tomando tres hallazgos al azar, que cada uno señala correctamente una discrepancia real entre el
código del backend y el código del frontend (no una suposición).

**Acceptance Scenarios**:

1. **Given** los inventarios de backend y frontend completos, **When** se construye la tabla de
   correspondencia, **Then** todo endpoint del backend aparece marcado como consumido o como no
   consumido por el frontend.
2. **Given** una llamada del frontend a un endpoint, **When** ese endpoint no existe en el
   backend o su contrato difiere, **Then** se registra como hallazgo en el Apéndice D, nunca como
   requisito funcional válido.
3. **Given** que el cruce front↔back terminó, **When** se presenta el resultado, **Then** el
   proceso se detiene explícitamente y espera confirmación del usuario antes de redactar el SRS
   completo (User Story 4).

---

### User Story 4 - Redacción del SRS completo con trazabilidad (Priority: P4)

Tras confirmar el resultado de la User Story 3, la misma persona necesita el documento final: una
SRS completa en formato IEEE 830 (con equivalencias a ISO/IEC/IEEE 29148), organizada por
módulo/dominio de negocio, con cada requisito trazado hacia su endpoint, pantalla y entidad de
datos, más los cinco apéndices (matriz de trazabilidad, equivalencia de normas, preguntas
abiertas para el Product Owner, discrepancias/riesgos, y cobertura real).

**Why this priority**: es el entregable final y depende por completo de que las tres historias
anteriores ya existan y hayan sido validadas; sin ellas, redactar el documento completo sería
repetir el riesgo de "inventar" que la regla central de esta función prohíbe.

**Independent Test**: se le entrega el documento SRS completo a alguien que no participó en el
análisis; debe poder tomar cualquier requisito al azar y seguir su trazabilidad hasta el
endpoint/pantalla/entidad citado, y confirmar que su etiqueta de evidencia es la correcta.

**Acceptance Scenarios**:

1. **Given** el resultado confirmado de las User Stories 1-3, **When** se redacta el SRS
   completo, **Then** el documento sigue la estructura completa definida (Introducción,
   Descripción general, Requisitos específicos, Apéndices A-E) sin omitir ninguna sección
   obligatoria.
2. **Given** un requisito cualquiera del documento, **When** se revisa su campo "Evidencia",
   **Then** la cita corresponde exactamente al archivo/línea, patrón, o pregunta abierta que
   dice representar.
3. **Given** un comportamiento identificado como defectuoso durante el análisis, **When** se
   redacta el documento final, **Then** ese comportamiento aparece en el Apéndice D de
   discrepancias, nunca normalizado como un requisito funcional vigente.

---

### Edge Cases

- ¿Qué pasa si un repositorio (backend o frontend) es demasiado extenso para analizarse por
  completo en una sola pasada? El proceso lo divide por módulos y declara explícitamente, en el
  propio documento, qué quedó fuera del análisis; nunca afirma cobertura total sin haberla
  verificado.
- ¿Qué pasa si el frontend llama a un endpoint que no existe en el backend, o con un contrato
  distinto al que el backend expone? Se registra como hallazgo en el Apéndice D, no como
  requisito funcional, y se marca como posible código muerto o contrato roto según corresponda.
- ¿Qué pasa si una validación de negocio existe solo en el frontend y no se repite en el backend?
  Se documenta explícitamente como riesgo de seguridad en el Apéndice D, dado que cualquier
  cliente distinto al frontend oficial podría saltársela.
- ¿Qué pasa si una spec interna de `pos-specs` describe un comportamiento de forma distinta al
  código real verificado? Prevalece el comportamiento real observado en el código (citado como
  [CÓDIGO]); la discrepancia con la spec interna se registra como hallazgo en el Apéndice D, no se
  oculta ni se resuelve a favor de la spec desactualizada.
- ¿Qué pasa si no hay evidencia suficiente para fijar un valor no funcional (tiempo de respuesta,
  límite de usuarios concurrentes, SLA, tasa de disponibilidad)? Se registra como pregunta abierta
  en el Apéndice C; nunca se asume un valor "típico de la industria" como si fuera un
  comportamiento verificado del sistema.
- ¿Qué pasa si el usuario no confirma, o pide cambios sobre el resultado de las User Stories 1-3?
  El proceso no avanza a la User Story 4 (redacción del documento completo) hasta recibir esa
  confirmación explícita.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El proceso DEBE generar un inventario del backend que cubra el 100% de los
  endpoints expuestos, cada uno con método, ruta, esquema de entrada/salida, autenticación
  requerida, roles/permisos y códigos de error posibles.
- **FR-002**: El proceso DEBE documentar el modelo de datos del backend: entidades, relaciones,
  restricciones de unicidad, claves foráneas, nulabilidad, checks, enums y migraciones relevantes.
- **FR-003**: El proceso DEBE documentar las reglas de negocio implementadas en la capa de
  servicios o casos de uso del backend: validaciones, cálculos, transiciones de estado y efectos
  secundarios.
- **FR-004**: El proceso DEBE documentar el mecanismo de autenticación y autorización del backend,
  incluida la expiración de sesión/token y el aislamiento multi-tenant.
- **FR-005**: El proceso DEBE documentar las integraciones externas del backend (APIs, colas,
  correo, pagos, almacenamiento, webhooks) que tengan evidencia verificable en el código.
- **FR-006**: El proceso DEBE documentar la configuración relevante del backend (variables de
  entorno, contenedores, CI/CD, tareas programadas) sin exponer ningún valor real de secreto,
  credencial o token.
- **FR-007**: El proceso DEBE usar los tests automatizados existentes del backend y del frontend
  como evidencia del comportamiento intencionado al documentar una regla o un flujo.
- **FR-008**: El proceso DEBE generar un inventario del frontend que cubra el 100% de las
  rutas/pantallas, con su guarda de navegación por rol.
- **FR-009**: Por cada pantalla del frontend, el proceso DEBE documentar las acciones de usuario,
  los formularios y sus validaciones de cliente, y los estados de vacío/carga/error cuando existan
  en el código.
- **FR-010**: Por cada pantalla del frontend, el proceso DEBE documentar cada llamada a la API
  consumida (cliente HTTP, endpoint exacto) y su manejo de errores observado en el código.
- **FR-011**: El proceso DEBE documentar el mecanismo de gestión de estado y de sesión del
  frontend.
- **FR-012**: El proceso DEBE construir una tabla de correspondencia que cubra el 100% de los
  endpoints del backend frente a su consumo (o no consumo) detectado en el frontend.
- **FR-013**: El proceso DEBE identificar y reportar explícitamente, como hallazgos: endpoints del
  backend no consumidos por el frontend, llamadas del frontend a endpoints inexistentes o con
  contrato distinto, validaciones presentes solo en el frontend, validaciones inconsistentes entre
  ambos lados, y roles/permisos aplicados en un lado pero no en el otro.
- **FR-014**: Cada afirmación del documento final DEBE llevar exactamente una etiqueta de
  evidencia — [CÓDIGO] con cita de archivo y línea, [INFERIDO] con el motivo de la inferencia
  explicado, o [PREGUNTA] — y ninguna afirmación puede quedar sin etiqueta.
- **FR-015**: El proceso NO DEBE registrar ninguna métrica de rendimiento, SLA, volumen de
  usuarios o límite de tasa que no esté respaldada por evidencia verificable en el código
  (timeouts, rate limits, índices, caché, paginación); en ausencia de esa evidencia, se registra
  una pregunta abierta en el Apéndice C, nunca una suposición en el cuerpo del documento.
- **FR-016**: Un comportamiento identificado como defectuoso (discrepancia entre lo esperado y lo
  observado, código muerto, riesgo detectado) NO DEBE registrarse como requisito funcional o no
  funcional; se documenta exclusivamente en el Apéndice D.
- **FR-017**: Cada requisito funcional o no funcional del documento final DEBE presentar los
  campos obligatorios: identificador, enunciado ("El sistema deberá..."), actor, precondiciones,
  entradas/salidas, reglas de negocio, criterio de aceptación verificable (Dado/Cuando/Entonces),
  prioridad, evidencia y trazabilidad hacia endpoint(s)/pantalla(s)/entidad(es).
- **FR-018**: Cada requisito DEBE evaluarse contra los ocho atributos de calidad de IEEE 830
  (correcto, inequívoco, completo, consistente, jerarquizado, verificable, modificable,
  trazable); cualquier atributo que no se cumpla DEBE marcarse explícitamente en el propio
  requisito.
- **FR-019**: El documento final DEBE seguir la estructura completa IEEE 830 acordada
  (Introducción, Descripción general, Requisitos específicos con sus subsecciones de interfaces
  externas/rendimiento/restricciones/atributos del sistema/datos, y los cinco apéndices A-E), sin
  omitir ninguna sección obligatoria.
- **FR-020**: El proceso DEBE detenerse explícitamente tras completar el inventario y el cruce
  front↔back (User Stories 1-3) y esperar confirmación expresa del usuario antes de redactar el
  documento SRS completo (User Story 4).
- **FR-021**: Si un repositorio resulta demasiado extenso para analizarse por completo en una sola
  pasada, el proceso DEBE procesarlo por módulos y declarar explícitamente, dentro del propio
  documento, qué quedó fuera del análisis.
- **FR-022**: El documento final DEBE incluir, en su Apéndice E, el porcentaje real de endpoints y
  de pantallas cubiertos por al menos un requisito documentado.
- **FR-023**: El documento resultante NO DEBE modificar, sustituir ni contradecir ninguna spec
  individual ya existente en `specs/` de este repositorio; es un artefacto nuevo y adicional de
  consolidación.
- **FR-024**: El proceso de análisis DEBE ser de solo lectura sobre `pos-backend` y
  `pos-heladeria`: en ningún momento modifica, ejecuta ni altera ningún archivo de ninguno de los
  dos repositorios.

### Key Entities *(include if feature involves data)*

- **Requisito funcional (RF)**: capacidad única que el sistema analizado ya ofrece, documentada
  con los campos obligatorios (enunciado, actor, criterio de aceptación, evidencia, trazabilidad)
  y agrupada por módulo/dominio de negocio.
- **Requisito no funcional (RNF)**: atributo de calidad del sistema analizado (seguridad,
  fiabilidad, disponibilidad, mantenibilidad, portabilidad, rendimiento) documentado solo cuando
  existe evidencia verificable; en caso contrario se convierte en pregunta abierta.
- **Endpoint**: ruta HTTP expuesta por el backend; unidad mínima de la tabla de correspondencia
  front↔back y del Apéndice A.
- **Pantalla/ruta de frontend**: unidad de navegación del frontend, con su guarda de rol, sus
  acciones de usuario y las llamadas a la API que realiza.
- **Entidad de datos**: tabla o modelo del backend, con sus atributos, relaciones y restricciones;
  base del modelo entidad-relación del documento final.
- **Etiqueta de evidencia**: clasificación obligatoria de toda afirmación del documento —
  [CÓDIGO], [INFERIDO] o [PREGUNTA] — que determina si una afirmación puede presentarse como
  hecho, como inferencia razonada, o si debe quedar como pregunta abierta.
- **Hallazgo (Apéndice D)**: discrepancia, inconsistencia, riesgo de seguridad o código muerto
  detectado durante el cruce front↔back o durante cualquier fase del inventario; nunca se
  convierte en requisito.
- **Pregunta abierta (Apéndice C)**: aspecto no determinable desde el código, priorizado por
  impacto, dirigido al Product Owner para su resolución futura.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los endpoints detectados en el backend aparece en la matriz de
  trazabilidad del documento final, y el Apéndice E reporta el porcentaje real de cobertura
  alcanzado tanto en endpoints como en pantallas.
- **SC-002**: El 100% de las afirmaciones del documento final lleva exactamente una etiqueta de
  evidencia; cero afirmaciones aparecen sin etiquetar en una revisión de muestreo.
- **SC-003**: Cero requisitos funcionales o no funcionales del documento describen un
  comportamiento defectuoso como si fuera una capacidad intencionada; toda discrepancia detectada
  aparece exclusivamente en el Apéndice D.
- **SC-004**: Un lector del documento final puede identificar, sin volver a revisar el código, el
  100% de los endpoints no consumidos por el frontend y de las inconsistencias de validación
  detectadas durante el cruce front↔back.
- **SC-005**: El proceso se detiene de forma verificable al terminar las User Stories 1-3 y solo
  continúa a la redacción completa del documento tras una confirmación explícita del usuario,
  registrada en el proceso.
- **SC-006**: El Apéndice C contiene únicamente preguntas genuinamente no determinables desde el
  código disponible; una auditoría de muestreo no encuentra ninguna pregunta que en realidad tenía
  evidencia verificable sin buscarse.

## Assumptions

- El análisis se realiza sobre el estado del código de `pos-backend` y `pos-heladeria` en el
  momento de ejecutar esta función; el documento final registra, en su sección de Referencias, la
  rama o el estado exacto analizado y la fecha del análisis.
- El documento SRS resultante es un artefacto nuevo y adicional de este mismo repositorio
  (`pos-specs`); no reemplaza, modifica ni resume ninguna de las specs individuales de
  funcionalidades ya existentes en `specs/`.
- El análisis es puramente de lectura sobre ambos repositorios (`pos-backend`, `pos-heladeria`);
  en ningún momento se ejecuta su código ni se modifica ninguno de sus archivos.
- Los diagramas exigidos (contexto del producto, entidad-relación) se entregan como código fuente
  de diagrama Mermaid embebido en el Markdown del documento, no como imágenes renderizadas,
  consistente con que esta función no produce capturas ni diagramas gráficos.
- La ubicación exacta de guardado del documento SRS final dentro del repositorio se decide en la
  fase de planificación de esta spec, no en esta especificación.
- El contenido previamente entregado bajo el alcance anterior de esta misma spec (carpeta
  `docs-publicos/` en la raíz del repositorio) permanece en el repositorio sin cambios, pero deja
  de estar asociado a esta spec; esta función no lo modifica ni depende de él.
- Los cuatro repositorios de referencia para verificar comportamiento real son exactamente
  `pos-backend` y `pos-heladeria` (hermanos de `pos-specs`); las specs ya existentes en
  `specs/` de este repositorio se usan como apoyo de contexto, nunca como sustituto de verificar
  directamente el código cuando ambas fuentes entren en conflicto.
