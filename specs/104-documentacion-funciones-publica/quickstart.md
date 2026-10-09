# Quickstart: validación del SRS por ingeniería inversa

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/](./contracts/)

Esta guía valida, sin ejecutar ni modificar `pos-backend` ni `pos-heladeria` (FR-024), que los
artefactos producidos por esta función cumplen los criterios de aceptación del spec (SC-001 a
SC-006). No requiere levantar ningún servidor ni base de datos: toda la verificación es lectura de
Markdown contra lectura de código fuente.

## Prerrequisitos

- Estar parado en la raíz de `pos-specs`, con `../pos-backend` y `../pos-heladeria` presentes como
  repositorios hermanos (clonados, no necesariamente en ejecución).
- Herramientas de búsqueda de texto disponibles (`grep`/`rg`) para verificar citas de código.

## 1. Cobertura del inventario de backend (US1 — Independent Test)

Con `specs/104-documentacion-funciones-publica/inventario-backend.md` ya producido:

1. Elegir tres endpoints al azar listados en el inventario.
2. Para cada uno, abrir la ruta de archivo:línea citada en su etiqueta `[CÓDIGO]` y confirmar que
   el método HTTP, la ruta, el esquema y los roles declarados coinciden exactamente con lo que
   está en el código.
3. Confirmar que el 100% de los módulos listados en la tabla "Resumen de alcance verificado" de
   `research.md` aparece representado en el inventario (o explícitamente declarado como fuera de
   alcance de esta pasada, con su razón — FR-021).

**Resultado esperado**: cero discrepancias entre lo citado y el código real; cero módulos sin
representar y sin declaración explícita de exclusión.

## 2. Cobertura del inventario de frontend (US2 — Independent Test)

Con `inventario-frontend.md` ya producido:

1. Elegir tres pantallas al azar.
2. Para cada una, confirmar la guarda de rol, las llamadas a la API citadas y sus validaciones de
   cliente contra el archivo:línea citado.
3. Confirmar que ninguna validación o estado de error fue documentado sin existir literalmente en
   el código (FR-009 del spec: "sin inventar ninguno que no esté presente").

**Resultado esperado**: cero validaciones o estados inventados; las tres citas de API resisten la
verificación manual contra el servicio real.

## 3. Cruce front↔back y punto de parada (US3 — Independent Test, SC-005)

Con `cruce-front-back.md` ya producido:

1. Confirmar que el 100% de los endpoints del inventario de backend aparece marcado como
   consumido, no consumido, o parcialmente consumido.
2. Elegir tres Hallazgos (`H-xx`) al azar y confirmar, leyendo ambos lados (backend y frontend),
   que cada uno describe una discrepancia real y no una suposición.
3. Confirmar que el documento termina con la sección fija "⏸ Punto de parada — pendiente de
   confirmación" (Decisión 5 de `research.md`) y que **no existe todavía ningún archivo** bajo
   `srs/` en la raíz del repositorio.
4. Solo tras una confirmación textual explícita del usuario sobre el resultado de este cruce se
   puede continuar al paso 4.

**Resultado esperado**: los tres hallazgos muestreados son reales y verificables; el documento
`srs/` no existe antes de la confirmación del usuario.

## 4. Verificación de etiquetado (SC-002, transversal a todos los artefactos)

Sobre cualquier artefacto ya producido (`inventario-backend.md`, `inventario-frontend.md`,
`cruce-front-back.md`, o ya en fase final, `srs/README.md` y sus apéndices):

1. Tomar una muestra de 10 oraciones declarativas sobre el comportamiento del sistema.
2. Confirmar que cada una lleva exactamente una etiqueta, con la sintaxis exacta de
   `contracts/formato-etiqueta-evidencia.md`.
3. Para cada `[PREGUNTA → C-xx]` de la muestra, confirmar que `C-xx` existe en el Apéndice C y que
   genuinamente no es determinable desde el código disponible (SC-006) — es decir, buscarla
   deliberadamente en el código antes de aceptar que es una pregunta legítima.

**Resultado esperado**: cero afirmaciones sin etiquetar en la muestra; cero preguntas de la
muestra que en realidad tenían evidencia verificable sin buscarse.

## 5. El documento final no normaliza defectos como requisitos (SC-003)

Sobre `srs/README.md` y `srs/apendices/d-discrepancias.md` ya producidos:

1. Tomar los Hallazgos del Apéndice D y confirmar que ninguno de ellos aparece también, redactado
   como capacidad intencionada, en la sección 3.2/3.5 de requisitos.
2. Tomar tres requisitos marcados con algún atributo IEEE 830 en ❌ (`contracts/plantilla-requisito.md`)
   y confirmar que, si el motivo del ❌ es una discrepancia real (no solo de redacción), existe su
   Hallazgo correspondiente en el Apéndice D.

**Resultado esperado**: ninguna intersección entre "comportamiento defectuoso documentado" y
"requisito vigente".

## 6. Trazabilidad completa y cobertura real (US4 — Independent Test, SC-001, SC-004)

Sobre el SRS final completo:

1. Tomar cualquier requisito al azar y seguir su campo "Trazabilidad" hasta el endpoint, pantalla
   o entidad citado en el Apéndice A; confirmar que existe y que la cita es coherente.
2. Confirmar que el Apéndice E reporta un porcentaje de cobertura de endpoints y de pantallas, y
   que ese porcentaje es consistente con contar manualmente las filas "cubierto"/"no cubierto" del
   Apéndice A sobre una muestra de 10 filas.
3. Sin volver a revisar el código, confirmar que es posible identificar desde el documento el
   100% de los endpoints no consumidos y de las inconsistencias de validación detectadas en el
   paso 3 de este quickstart.

**Resultado esperado**: la trazabilidad de la muestra resiste la verificación; el porcentaje del
Apéndice E es coherente con el conteo manual; toda la información de endpoints no consumidos e
inconsistencias es recuperable solo desde el documento.

## 7. Estructura completa sin secciones omitidas (FR-019)

1. Comparar el índice real de `srs/README.md` contra `contracts/estructura-srs-ieee830.md`.
2. Confirmar que las cinco secciones de apéndice existen como archivos independientes bajo
   `srs/apendices/` y están enlazadas desde `srs/README.md`.

**Resultado esperado**: coincidencia 1 a 1 entre el índice del contrato y el índice real del
documento entregado; ninguna sección obligatoria falta ni aparece vacía sin la declaración
explícita exigida en `contracts/estructura-srs-ieee830.md`.

## 8. El SRS no modifica ni contradice specs existentes (FR-023)

Sobre `srs/README.md` ya redactado:

1. Para cada requisito (RF/RNF) cuyo módulo coincida con el de una spec individual ya
   implementada en `specs/`, leer esa spec y confirmar que el requisito del SRS no la
   contradice ni la sustituye — solo la documenta como comportamiento ya existente.
2. Confirmar que ningún archivo fuera de `srs/` o de
   `specs/104-documentacion-funciones-publica/` fue creado o modificado por esta función.

**Resultado esperado**: cero contradicciones detectadas entre el SRS y las specs
individuales existentes; cero archivos modificados fuera del alcance de esta función.
