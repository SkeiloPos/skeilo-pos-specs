# Apéndice B — Equivalencia de normas (IEEE 830-1998 ↔ ISO/IEC/IEEE 29148:2018)

**SRS**: [../README.md](../README.md)

Este SRS sigue la estructura IEEE 830-1998 como norma primaria, por ser la convención histórica más extendida en el dominio y la acordada para esta documentación. La tabla siguiente, tomada de [estructura-srs-ieee830.md](../../specs/104-documentacion-funciones-publica/contracts/estructura-srs-ieee830.md), documenta su equivalencia con las cláusulas correspondientes de ISO/IEC/IEEE 29148:2018 (la norma que formalmente sucede y absorbe a IEEE 830), de modo que el documento sea interpretable bajo cualquiera de las dos convenciones.

| # | Sección IEEE 830-1998 | Equivalencia ISO/IEC/IEEE 29148:2018 | Contenido |
|---|---|---|---|
| 1 | Introducción | Cláusula 5 (Introduction) | Propósito, alcance, definiciones/acrónimos, referencias (specs internas consultadas, rama/commit de `pos-backend` y `pos-heladeria` analizados, fecha), visión general del documento |
| 2 | Descripción general | Cláusula 6.1-6.3 (Overall description) | Perspectiva del producto, funciones principales (resumen por módulo), características de los usuarios/roles, restricciones generales, supuestos y dependencias |
| 3.1 | Requisitos de interfaces externas | Cláusula 9.4 (Interfaces) | Interfaces de usuario (pantallas, por remisión al inventario de frontend), interfaces de software (endpoints, por remisión al inventario de backend), interfaces de comunicación (protocolo HTTP, SSE) |
| 3.2 | Requisitos funcionales | Cláusula 9.3 (Functional requirements) | Todos los RF, agrupados por módulo/dominio de negocio, con la plantilla de `plantilla-requisito.md` |
| 3.3 | Requisitos de rendimiento | Cláusula 9.5 (Performance) | Solo afirmaciones con evidencia verificable (índices, paginación, timeouts, caché observados); el resto va al Apéndice C |
| 3.4 | Restricciones de diseño | Cláusula 9.6 (Design constraints) | Restricciones verificadas (versión de framework, convenciones de arquitectura multi-tenant, etc.) |
| 3.5 | Atributos del sistema | Cláusula 9.7 (System attributes / Quality) | RNF de seguridad, fiabilidad, disponibilidad, mantenibilidad, portabilidad, con la misma plantilla de requisito |
| 3.6 | Requisitos de datos | Cláusula 9.4.4 / Anexo de datos | Modelo entidad-relación (diagrama Mermaid) y detalle por entidad, por remisión a `inventario-backend.md` |
| A | Apéndice A — Matriz de trazabilidad | Anexo de trazabilidad (Cláusula 8) | Todo RF/RNF ↔ endpoint(s)/pantalla(s)/entidad(es); todo endpoint marcado consumido/no consumido |
| B | Apéndice B — Equivalencia de normas | — | Esta misma tabla, documentada como parte entregada del SRS |
| C | Apéndice C — Preguntas abiertas | — | Aspectos no determinables desde el código, dirigidos al Product Owner |
| D | Apéndice D — Discrepancias y riesgos | — | Todos los Hallazgos (`H-xx`) del cruce front↔back |
| E | Apéndice E — Cobertura real | — | % de endpoints y de pantallas con al menos un requisito documentado |

## Notas sobre la equivalencia

- IEEE 830-1998 fue retirada formalmente y sucedida por ISO/IEC/IEEE 29148:2018, que fusiona la gestión de requisitos de sistema y de software en un solo estándar. La correspondencia no es 1 a 1 en varias secciones — 29148 no numera sus cláusulas de la misma manera — por lo que la columna de equivalencia señala la cláusula temática más cercana, no un calco literal de numeración.
- Los apéndices A-E de este SRS no tienen una sección homóloga numerada en IEEE 830-1998; se agregaron como extensión de trazabilidad exigida por el spec de esta función (FR-017, FR-019), alineada con el énfasis de 29148 en trazabilidad bidireccional (Cláusula 8).
- Este documento no declara conformidad formal con ninguna de las dos normas (no fue auditado por un tercero contra el checklist completo de ninguna de ellas); la tabla es una guía de lectura cruzada, no una certificación.
