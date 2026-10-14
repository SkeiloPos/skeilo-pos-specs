# Contrato — Transición de navegación (barra de carga, skeleton, aparición escalonada)

**Spec**: [../spec.md](../spec.md) (Historia 4, FR-019 a FR-022, SC-008, SC-009) | **Research**:
[../research.md](../research.md) R20, R21 | **Data model**: [../data-model.md](../data-model.md) §6.1

**Nuevo en la iteración 2026-10-13.** No existe equivalente en la iteración anterior.

## 1. `NavigationTransitionService` — contrato público

```ts
@Injectable({ providedIn: 'root' })
export class NavigationTransitionService {
  readonly phase: Signal<'idle' | 'out' | 'skeleton' | 'in'>;  // data-model §6.1
  readonly barVisible: Signal<boolean>;
  readonly barProgress: Signal<0 | 75 | 100>;                  // ancho simulado de la barra, no un porcentaje real
}
```

**Garantías**:
- `phase()` nunca queda "pegada" en `'out'`/`'skeleton'` indefinidamente: toda transición termina
  en `'in'` (navegación completada) o vuelve a `'idle'` (`NavigationCancel`/`NavigationError`).
- Un `NavigationStart` nuevo mientras `phase() !== 'idle'` **reinicia** la coreografía desde
  `'out'` — nunca dos coreografías corriendo a la vez (Historia 4, Escenario 5).
- Solo reacciona a una navegación cuyo *path* (sin query string) cambió respecto al anterior — un
  cambio de solo query params (filtros, paginación) no dispara `phase()`.
- Acotado a `!isSuperAdmin()` — el panel de Super Admin nunca ve esta coreografía (mismo criterio
  que el resto de la spec, research R1, reafirmado en R20).

## 2. Contrato de tiempos (FR-019, "duración breve y fija")

Los tiempos exactos replican la coreografía ya aprobada de `Layout base.dc.html` (research R20,
líneas 87-91 del script del archivo) — no son una decisión de negocio nueva, son una réplica de un
comportamiento visual ya validado:

| Transición | Disparador | Duración aproximada |
|---|---|---|
| `'idle'` → `'out'` | `NavigationStart` (path distinto) | inmediato; contenido anterior se desvanece ~150ms |
| `'out'` → `'skeleton'` | cronómetro fijo | ~170ms después de `'out'` |
| `'skeleton'` → `'in'` | lo último entre (cronómetro fijo ~230ms) y (`NavigationEnd` real) | — |
| `'in'` → `'idle'` | la barra termina de desvanecerse | ~900ms después de `'in'` |

**Garantía de no-regresión** (navegación fría, chunk perezoso aún descargando): `'skeleton'` nunca
avanza a `'in'` antes de que `NavigationEnd` dispare, sin importar cuánto tarde — el cronómetro fijo
solo establece un **mínimo**, nunca un máximo.

## 3. Contrato del skeleton genérico (FR-021)

- Contenido **fijo**, nunca derivado de los datos reales de la sección destino (research R20:
  escalonar filas reales de una tabla de 200 ítems no es viable).
- Mismo efecto de aparición gradual que el contenido real (§4), **sin** brillo/pulso adicional
  (Clarification sesión 2026-10-13).
- No sustituye ni oculta los spinners/estados de carga internos que cada módulo ya use para sus
  propias peticiones — esos siguen funcionando exactamente igual después de que `phase()` llegue a
  `'in'`.

## 4. Contrato de aparición escalonada del contenido real (FR-020)

Se aplica **únicamente** a los hijos directos de nivel superior del componente que `router-outlet`
monta (research R20: verificado contra páginas reales — 3 a 6 secciones de nivel superior por
página típicamente: cabecera, pestañas/filtros, alerta, tabla/formulario principal) — **nunca** a
elementos anidados más profundo (filas de tabla, tarjetas de una grilla). El retraso escalonado
tiene un tope: los hijos más allá de un número fijo comparten el retraso del último, en vez de
seguir acumulando. Ningún módulo necesita una clase/directiva propia para participar — el selector
es genérico, aplicado una sola vez sobre el contenedor de `router-outlet` en `styles.css`.

**Garantía de no-touch**: ningún archivo de los ~18 módulos de tenant se modifica para que esta
animación funcione (Assumptions de la spec).

## 5. Contrato de `prefers-reduced-motion` (FR-022)

```css
@media (prefers-reduced-motion: reduce) {
  /* las reglas de transición/animación de la barra y del contenedor de aparición escalonada
     quedan sin efecto — el cambio de contenido sigue siendo instantáneo y funcional */
}
```

**Garantía**: esta regla **no** se extiende retroactivamente a las transiciones ya shippeadas de la
iteración anterior (colapso de sidebar, drawer móvil/tablet) — FR-022 cita, por nombre, solo
FR-019/FR-020 (research R21). Tampoco bloquea ninguna lógica: `NavigationTransitionService` sigue
calculando sus fases igual bajo este media query, solo que ninguna regla CSS tiene una transición
que ejecutar.

## 6. Qué pasa con Super Admin

No ve ninguna barra, skeleton ni animación de aparición — su `<router-outlet>` nunca está envuelto
por el contenedor de transición (misma bifurcación `isSuperAdmin()` de siempre, research R1).
