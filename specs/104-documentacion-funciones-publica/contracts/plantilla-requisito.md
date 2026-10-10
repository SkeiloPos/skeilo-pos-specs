# Contrato: plantilla de Requisito (RF/RNF)

Todo requisito funcional o no funcional del SRS final (`srs/README.md`) usa exactamente esta
estructura de campos, en este orden (deriva de FR-017 y de la entidad "Requisito
funcional/Requisito no funcional" en `data-model.md`).

```markdown
#### RF-<módulo>-<secuencial>: <título corto>

- **Enunciado**: El sistema deberá <capacidad única, verificable>.
- **Actor**: <rol>
- **Precondiciones**: <estado previo necesario> [etiqueta de evidencia]
- **Entradas**: <esquema/payload> [etiqueta de evidencia]
- **Salidas**: <esquema/respuesta> [etiqueta de evidencia]
- **Reglas de negocio**:
  - <regla 1> [etiqueta de evidencia]
  - <regla 2> [etiqueta de evidencia]
- **Criterio de aceptación**:
  - **Dado** <contexto>, **cuando** <acción>, **entonces** <resultado verificable> [etiqueta de evidencia]
- **Prioridad**: Alta | Media | Baja — <justificación breve>
- **Trazabilidad**: Endpoint(s): <método + ruta>; Pantalla(s): <ruta frontend>; Entidad(es): <nombre de modelo>
- **Atributos IEEE 830**: Correcto ✅/❌ · Inequívoco ✅/❌ · Completo ✅/❌ · Consistente ✅/❌ · Jerarquizado ✅/❌ · Verificable ✅/❌ · Modificable ✅/❌ · Trazable ✅/❌
  - <si algún atributo es ❌, una frase explicando por qué y qué falta>
```

## Reglas de uso

- Un requisito describe **una sola capacidad**. Si una oración "El sistema deberá X y también Y"
  mezcla dos capacidades independientes, se separa en dos requisitos.
- El identificador `<módulo>` coincide con el nombre de módulo usado en `inventario-backend.md`
  (p. ej. `RF-orders-003`), no con una taxonomía distinta.
- Todo requisito marcado como ❌ en algún atributo IEEE 830 debe, además, tener una entrada
  correspondiente en el Apéndice D si el motivo del ❌ es una discrepancia o ambigüedad real del
  sistema (no solo una limitación de redacción).
- Para RNF, los campos "Entradas/Salidas" pueden no aplicar; cuando no aplican se omiten, nunca se
  dejan como `N/A` sin explicación cuando exista una razón específica digna de registrarse.
