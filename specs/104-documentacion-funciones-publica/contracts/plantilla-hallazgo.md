# Contrato: plantilla de Hallazgo (Apéndice D)

Todo hallazgo detectado durante el cruce front↔back o durante cualquier fase del inventario usa
esta estructura (deriva de FR-013/FR-016 y de la entidad "Hallazgo" en `data-model.md`).

```markdown
#### H-<secuencial>: <título corto>

- **Categoría**: endpoint no consumido | contrato distinto | validación solo-frontend | validación inconsistente | rol inconsistente | código muerto | otro
- **Severidad**: Alta | Media | Baja — <justificación breve>
- **Backend**: <qué hace/expone el backend> [etiqueta de evidencia]
- **Frontend**: <qué hace/espera el frontend, o su ausencia> [etiqueta de evidencia]
- **Discrepancia**: <en qué consiste exactamente la diferencia entre ambos lados>
- **Entidades afectadas**: Endpoint(s): <método + ruta>; Pantalla(s): <ruta frontend>
- **Riesgo si no se corrige**: <consecuencia concreta, p. ej. "cualquier cliente HTTP distinto al frontend oficial puede saltarse esta validación">
```

## Reglas de uso

- Un hallazgo **nunca** se reescribe como requisito funcional o no funcional, ni siquiera cuando
  describe un comportamiento "deseable" — FR-016 lo prohíbe sin excepción.
- Las cinco primeras categorías son obligatorias de cubrir cuando existan instancias reales
  (FR-013); "otro" se usa solo cuando ninguna de las cinco aplica.
- Todo hallazgo de categoría "validación solo-frontend" se marca automáticamente con severidad
  mínima Media, dado que implica un riesgo de seguridad potencial (un cliente distinto al
  frontend oficial podría omitir esa validación), salvo justificación explícita de por qué no
  aplica en ese caso concreto.
