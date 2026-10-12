# Quickstart — Validación de la spec 116

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/](./contracts/)

Guía de validación de extremo a extremo. Los pasos 1 a 3 son automáticos (Vitest); del 4 en
adelante son recorrido manual — lo que un test de `TestBed` no puede observar de verdad: foco de
teclado real, parpadeo visual, redimensionado en vivo del navegador y auditoría de Lighthouse.

## 0. Prerrequisitos

```bash
cd ../pos-heladeria
npm install          # solo si se añadieron tipos de @angular/cdk/layout que no se usaban antes
npm start             # ng serve — http://localhost:4200
```

No se necesita `pos-backend` corriendo con datos especiales: esta spec no toca el backend. Sí
hace falta una sesión real (login) con al menos un usuario `ADMIN` o `CASHIER` con un plan que
incluya `inventario`/`promociones`, para poder ver los 6 grupos completos, y uno `MESERO` para
verificar que su sidebar reducido sigue mostrando solo sus ítems de siempre.

### Línea base de la suite, antes de tocar nada

```bash
npm test
```

Anotar cuántos tests pasan/fallan **antes** de implementar (ver memoria del proyecto sobre los
fallos preexistentes de la suite frontend — no son de esta spec). Cualquier fallo nuevo después
de implementar es una regresión de esta spec hasta que se demuestre lo contrario.

## 1. `PanelThemeService` y persistencia (FR-009 a FR-014)

Tests nuevos en `panel-theme.service.spec.ts`:
- Sin nada guardado y sin señal de sistema → `'light'`.
- Sin nada guardado y `matchMedia('(prefers-color-scheme: dark)').matches = true` (mockeado) →
  `'dark'`.
- Con `pos.panel.theme = 'dark'` guardado → `'dark'`, **sin** consultar `matchMedia` (se puede
  verificar con un spy que nunca se llama).
- `localStorage.getItem`/`setItem` lanzando → no se propaga la excepción, y el signal sigue
  cambiando en memoria.

## 2. Verificación visual del cascarón (FR-001 a FR-003, FR-012)

1. Login como `ADMIN`. Confirmar los 6 grupos (Inicio, Operación, Catálogo, Inventario, Control,
   Administración) con los ítems y etiquetas de
   [contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md) —
   comparar uno a uno contra la tabla, en particular "Cajas" (no "Caja") y "Terminal de Mesas"/
   "Carta del Menú" con mayúscula.
2. Con DevTools → Application → Local Storage, fijar `pos.panel.theme = "dark"` manualmente y
   recargar (F5, no navegación SPA). El primer frame visible debe mostrar ya el marco oscuro —
   grabar con el panel *Performance* (CPU 4x throttling) si hay duda visual a ojo.
3. Borrar la clave y recargar en una ventana de incógnito (storage bloqueado o simplemente
   limpio): el panel debe cargar en claro, sin ningún error en la consola (SC-003).
4. Confirmar que el área de contenido (`<router-outlet>`) se desplaza de forma independiente del
   Sidebar y del Navbar (FR-015): con una pantalla larga de cualquier módulo (por ejemplo,
   Inventario con muchos ítems), hacer scroll dentro del contenido y confirmar que el Sidebar y
   el Navbar permanecen fijos — comportamiento heredado sin cambios (research.md R12).

## 3. Historia 1 — Navegación y estructura rediseñadas (P1)

1. Repetir el login con `CASHIER` y con `MESERO`: cada uno debe ver únicamente los grupos/ítems
   que ya veía antes del rediseño (comparar contra `navigation.config.ts` roles/moduleKey — la
   columna de acceso no cambió, solo la presentación).
2. Navegar a cada ítem del sidebar; confirmar que se resalta como activo (FR-004) y que el título
   del navbar (`frame.label`) cambia junto con él.
3. Forzar (vía DevTools, condición de red o un plan de prueba sin `inventario` ni `promociones`)
   que el grupo "Inventario" quede sin ítems visibles: el grupo completo debe desaparecer, no
   mostrarse vacío (FR-016 — mismo criterio que ya está probado hoy en `SidebarComponent`,
   verificar que se sostiene en el componente nuevo).
4. Colapsar el sidebar en escritorio (botón de menú). Confirmar: (a) la vista actual no cambia ni
   recarga; (b) cada ícono, al enfocarse con Tab (sin mouse), muestra su tooltip con el nombre
   completo del ítem (FR-007). Recargar la página: el sidebar debe volver colapsado, sin mostrar
   primero la versión expandida.

## 4. Historia 2 — Tema claro/oscuro (P2)

1. Clic en el interruptor de tema del navbar. Confirmar el cambio inmediato de paleta en
   sidebar/navbar/fondo, y que el contenido de la página actual (una tabla o un formulario de
   cualquier módulo) **no cambia** de apariencia (FR-010).
2. Recargar: el tema oscuro persiste sin parpadeo (repetir la verificación de Performance del
   paso 2.2 si se quiere evidencia grabada).
3. En una ventana de incógnito con el storage bloqueado deliberadamente (DevTools → Application →
   "Block all storage" o equivalente), cargar el panel: debe verse en el tema por defecto, sin
   errores en consola (SC-003).
4. Cambiar la preferencia de tema del sistema operativo con una preferencia explícita ya guardada
   en el panel: la preferencia guardada debe prevalecer (Edge Case de la spec).

## 5. Historia 3 — Uso en pantallas pequeñas (P3)

1. Con DevTools en modo responsive, fijar el ancho en 900px (< 1024px): el sidebar debe
   ocultarse por defecto y aparecer un botón de menú/hamburguesa.
2. Abrir el drawer, confirmar el scrim (fondo oscurecido) y que seleccionar un ítem o tocar fuera
   del menú lo cierra (Historia 3, Escenario 2).
3. **Sin recargar**, arrastrar el ancho de la ventana de 900px a 1200px y de vuelta a 900px varias
   veces: el layout debe alternar entre modo escritorio (con el colapso que tenía guardado) y modo
   drawer, sin perder el módulo que se estaba viendo (Edge Case de cruce de punto de quiebre en
   vivo — es el único punto de esta spec sin equivalente hoy, verificar con especial atención).

## 6. Indicador de caja en el navbar (Assumptions, research R8)

1. Login como `CASHIER` **sin** haber abierto antes Caja ni Terminal de Mesas en esta sesión, con
   un turno ya abierto desde otro dispositivo/sesión. El navbar debe mostrar "Caja abierta" (o el
   estado equivalente) sin que el usuario tenga que visitar esas pantallas primero.
2. Login como `MESERO`: el indicador de caja no debe aparecer en su navbar (no tiene acceso a
   Caja).

## 7. Auditoría de accesibilidad (SC-006)

Con Lighthouse (DevTools → Lighthouse → categoría Accessibility, o
`mcp__chrome-devtools__lighthouse_audit` si se corre desde el agente):
1. Auditar una pantalla cualquiera del panel en tema claro → puntuación 100.
2. Cambiar a tema oscuro, auditar la misma pantalla → puntuación 100.
3. Revisar manualmente el contraste de `--panel-color-text-*` sobre `--panel-color-surface`/
   `--panel-color-canvas` en ambos temas contra WCAG 2.1 AA (4.5:1 texto normal, 3:1 texto
   grande) — los valores de [contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md)
   §2 ya vienen del sistema de diseño, pero la combinación específica que el marco use debe
   confirmarse, no asumirse.

## 8. Regresión (Principios II, III, X)

```bash
npm test
```

- Cero tests nuevos en rojo.
- `sidebar.component.spec.ts`, `header.component.spec.ts`, `dashboard-layout.component.spec.ts`
  (legado) siguen en verde **sin haberlos tocado** — es la prueba de que Super Admin no se vio
  afectado (research R1).
- Ningún test `"CONGELA comportamiento actual:"` tocado (no hay ninguno en esta área — research,
  verificación de `CONGELA`).
- El conteo de fallos preexistentes de la suite frontend no debe subir respecto a la línea base
  del paso 0 (más allá de los ya conocidos y documentados en la memoria del proyecto).

## 9. Lista de cierre

- [ ] Los 6 grupos, etiquetas e íconos coinciden con
      [contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md).
- [ ] Cero regresiones de acceso por rol/plan (SC-004).
- [ ] Tema oscuro persistente, sin parpadeo, con *fallback* correcto sin storage (SC-002, SC-003).
- [ ] Colapso de escritorio persistente con tooltip accesible por teclado (FR-007, FR-017).
- [ ] Drawer móvil/tablet con scrim y cierre correcto (SC-005).
- [ ] Punto de quiebre reactivo en vivo, sin recargar (Edge Case).
- [ ] Lighthouse Accessibility = 100 en ambos temas (SC-006).
- [ ] Super Admin, verificado visualmente, **sin ningún cambio** (R1).
