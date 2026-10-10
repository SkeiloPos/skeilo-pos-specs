# Contrato: estructura obligatoria de `srs/README.md` (IEEE 830 + equivalencias 29148)

Índice completo que `srs/README.md` debe seguir sin omitir ninguna sección (FR-019). La columna
"Equivalencia 29148" alimenta directamente el Apéndice B.

| # | Sección IEEE 830-1998 | Equivalencia ISO/IEC/IEEE 29148:2018 | Contenido |
|---|---|---|---|
| 1 | Introducción | Cláusula 5 (Introduction) | Propósito, alcance, definiciones/acrónimos, referencias (specs internas consultadas, rama/commit de `pos-backend` y `pos-heladeria` analizados, fecha), visión general del documento |
| 2 | Descripción general | Cláusula 6.1-6.3 (Overall description) | Perspectiva del producto, funciones principales (resumen por módulo), características de los usuarios/roles, restricciones generales, supuestos y dependencias |
| 3.1 | Requisitos de interfaces externas | Cláusula 9.4 (Interfaces) | Interfaces de usuario (pantallas, por remisión al inventario de frontend), interfaces de software (endpoints, por remisión al inventario de backend), interfaces de comunicación (protocolo HTTP, WebSocket si existe evidencia) |
| 3.2 | Requisitos funcionales | Cláusula 9.3 (Functional requirements) | Todos los RF, agrupados por módulo/dominio de negocio, con la plantilla de `contracts/plantilla-requisito.md` |
| 3.3 | Requisitos de rendimiento | Cláusula 9.5 (Performance) | Solo afirmaciones con evidencia verificable (índices, paginación, timeouts, caché observados); el resto va al Apéndice C |
| 3.4 | Restricciones de diseño | Cláusula 9.6 (Design constraints) | Restricciones verificadas (versión de framework, convenciones de arquitectura multi-tenant, etc.) |
| 3.5 | Atributos del sistema | Cláusula 9.7 (System attributes / Quality) | RNF de seguridad, fiabilidad, disponibilidad, mantenibilidad, portabilidad, con la misma plantilla de requisito |
| 3.6 | Requisitos de datos | Cláusula 9.4.4 / Anexo de datos | Modelo entidad-relación (diagrama Mermaid) y detalle por entidad, por remisión a `data-model.md` de la ejecución (inventario de backend) |
| A | Apéndice A — Matriz de trazabilidad | Anexo de trazabilidad (Cláusula 8) | Todo RF/RNF ↔ endpoint(s)/pantalla(s)/entidad(es); todo endpoint marcado consumido/no consumido |
| B | Apéndice B — Equivalencia de normas | — | Esta misma tabla, documentada como parte entregada del SRS |
| C | Apéndice C — Preguntas abiertas | — | Plantilla de la entidad "Pregunta abierta" en `data-model.md` |
| D | Apéndice D — Discrepancias y riesgos | — | Todos los Hallazgos, con `contracts/plantilla-hallazgo.md` |
| E | Apéndice E — Cobertura real | — | % de endpoints y de pantallas con al menos un requisito documentado (FR-022), más qué módulos quedaron fuera de alcance si aplica (FR-021) |

## Reglas de uso

- Ninguna de las filas 1 a 3.6 ni los apéndices A-E puede faltar en la versión final, aunque su
  contenido sea breve — si no hay nada verificable que reportar en una subsección (p. ej. 3.3
  Rendimiento sin ninguna evidencia de código), la subsección existe igual y declara
  explícitamente "sin evidencia verificable de código; ver preguntas abiertas C-xx a C-yy", nunca
  se omite la sección completa.
- La sección 2 (Descripción general) es la única que puede redactarse como síntesis narrativa sin
  etiqueta de evidencia oración por oración, siempre que cada afirmación concreta que contenga
  (número de módulos, roles existentes) remita a la sección 3 correspondiente donde sí está
  etiquetada.
- El diagrama de contexto del producto y el diagrama entidad-relación (Asunciones del spec) se
  insertan como bloques de código Mermaid embebidos directamente en la sección 2 y 3.6
  respectivamente.
