# Quickstart — Validación de la spec 116

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/](./contracts/)

Guía de validación de extremo a extremo. Los pasos 1 a 3 son automáticos (Vitest); del 4 en
adelante son recorrido manual — lo que un test de `TestBed` no puede observar de verdad: foco de
teclado real, parpadeo visual, redimensionado en vivo del navegador y auditoría de Lighthouse.

> **Los pasos 1 a 8 validan la iteración 2026-10-12** (ya implementada y fusionada a `develop`).
> **Los pasos 10 a 15 validan la iteración 2026-10-13** (tema global + micro-interacciones de
> carga), y el 16 es la lista de cierre combinada de ambas iteraciones (reemplaza al §9 original de
> la primera iteración, fusionado aquí) — el paso 4 original se reescribió para reflejar el alcance
> ampliado de FR-010; el resto de los pasos 1-8 sigue vigente sin cambios.

## 0. Prerrequisitos

```bash
cd ../pos-heladeria
npm install          # sin paquetes nuevos en ninguna de las dos iteraciones — @angular/cdk/layout
                      # y @angular/cdk/overlay ya eran dependencias existentes (research R6, R18)
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

> **Reescrito en la iteración 2026-10-13**: el paso 1 original decía que el contenido de la página
> **no** cambiaba de apariencia — eso era FR-010 en su alcance original (solo marco). FR-010 se
> amplió; ver el paso 10 para la verificación completa del alcance ampliado.

1. Clic en el interruptor de tema del navbar. Confirmar el cambio inmediato de paleta en
   sidebar/navbar/fondo **y en el contenido de la página actual** (tablas, formularios, tarjetas —
   FR-010 ampliado, verificación completa en el paso 10).
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

## 10. Tema oscuro ampliado a los ~18 módulos (FR-010, SC-007) — nuevo, 2026-10-13

1. **Antes que nada**: con Terminal de Mesas ya normalizada (unidad 8 del plan), confirmar en tema
   **claro** que no cambió nada — el objetivo de esa normalización es cero diferencia visual.
   Cualquier diferencia encontrada aquí es un error de la sustitución hex→clase, no un ajuste.
2. Activar tema oscuro. Recorrer al menos: Inventario (tabla + filtros + modal de compra),
   Ventas, Terminal de Mesas (POS de mostrador completo — pestañas, carrito, pago), Usuarios
   (tabla + modal), Reportes (gráficas, ver paso 13), Promociones (tabla + el desplegable de CDK,
   ver paso 12). Confirmar que no queda ningún elemento en paleta clara sobre fondo oscuro, salvo
   insignias/badges de estado (`bg-amber-50`, `bg-red-50`, etc. — se dejan igual a propósito,
   research R16) y los acentos de marca (`indigo-*`, fuera de alcance, research R16).
3. Documentar cualquier combinación rota como un hallazgo puntual (research R16: "ningún valor se
   da por bueno sin verlo renderizado") — no se espera una lista exhaustiva previa, se espera que
   esta verificación la genere.

## 11. Superficies que deben resistir el tema (FR-010, research R17) — nuevo, 2026-10-13

1. Con tema oscuro activo, abrir el reporte de cierre de un turno (Caja → cerrar turno) y la hoja
   de códigos QR de mesas (`/dashboard/mesas/qr` o equivalente). Ambas deben verse **siempre
   claras**, sin importar el tema activo del resto del panel.
2. Imprimir (o Vista previa de impresión) ambas superficies con tema oscuro activo: el resultado
   impreso debe ser idéntico al que se vería con tema claro activo.
3. Confirmar que un ticket/factura impreso (`receipt.util.ts`) no se vio afectado por ningún cambio
   de esta iteración (ya estaba aislado en iframe, research R17) — no debería haber nada que
   verificar aquí más allá de que siga imprimiendo igual que antes.

## 12. Overlay de CDK y modales (FR-010) — nuevo, 2026-10-13

1. Con tema oscuro activo, en Promociones, abrir el menú de acciones por fila (el único
   `cdkConnectedOverlay` del panel). Debe verse en paleta oscura, igual que el resto de la
   pantalla — sin esto, quedaría congelado en claro (research R18).
2. Abrir cualquier modal de formulario de otro módulo (p. ej. "Nuevo insumo" en Inventario, o
   cualquiera de los ~33 modales `fixed inset-0` del panel) y confirmar que también respeta el
   tema — estos no deberían necesitar ningún ajuste (ya heredan por estar dentro del árbol), así
   que esta verificación es una prueba negativa.

## 13. Gráficas (FR-010, research R19) — nuevo, 2026-10-13

1. En Reportes, con tema claro, confirmar que las gráficas se ven igual que antes de esta
   iteración (ejes, rejilla, tooltip, paleta de series).
2. Cambiar a tema oscuro: los ejes/rejilla/tooltip deben adaptarse; la paleta categórica de las 5
   series de datos debe **mantenerse igual** en ambos temas (research R19 — identifican datos, no
   superficie).

## 14. Barra de carga, skeleton y aparición escalonada (Historia 4, FR-019 a FR-022) — nuevo, 2026-10-13

1. Navegar entre dos secciones del sidebar (p. ej. Inventario → Ventas): confirmar que aparece
   brevemente una barra de carga delgada en la parte superior del panel, que recorre su ancho y
   desaparece.
2. Confirmar que, durante la transición, se ve un skeleton genérico (no el contenido real a medio
   cargar, ni una pantalla en blanco) y que el contenido real, al aparecer, lo hace con un efecto
   de aparición gradual escalonado por sección (cabecera, luego tabla/formulario, etc. — no todo
   de golpe).
3. Repetir en un módulo con una tabla grande (Inventario con muchos ítems): confirmar que el
   escalonado **no** se nota fila por fila — solo las secciones de nivel superior de la página
   (research R20).
4. Clics rápidos y sucesivos en 3-4 ítems del sidebar antes de que termine cada transición: el
   panel debe terminar mostrando únicamente la última sección elegida, sin barra a medio recorrido
   ni mezcla de contenido (Historia 4, Escenario 5).
5. Con DevTools → Rendering → "Emulate CSS media feature prefers-reduced-motion: reduce" activado:
   repetir el paso 1 — el contenido debe cambiar de forma inmediata, sin barra ni animación de
   aparición, sin errores ni transición a medio camino (FR-022, SC-009).
6. Confirmar que Super Admin **no** ve ninguna barra ni skeleton al navegar entre sus pantallas
   (research R1/R20 — fuera de alcance por construcción).
7. Confirmar que el área de contenido sigue con scroll independiente del Sidebar/Navbar (FR-015)
   tras el nuevo contenedor de transición/skeleton que envuelve el `router-outlet` — mismo criterio
   que ya rompió una vez el tooltip del sidebar colapsado (T029, regla `overflow` contradictoria de
   CSS2.1).

## 15. Regresión ampliada (Principios II, III, X) — nuevo, 2026-10-13

```bash
npm test
```

- Cero tests nuevos en rojo (`navigation-transition.service.spec.ts`,
  `chart-theme.spec.ts` ampliado, los 3 `*chart*.component.spec.ts` ampliados).
- Los tests existentes de Terminal de Mesas (los 11 archivos normalizados) siguen en verde sin
  cambios de aserciones — la normalización es visual/de clases, no de comportamiento.
- Línea base de la suite sin subir respecto al paso 0 (memoria del proyecto: nunca correr
  frontend+backend completos en paralelo).

## 16. Lista de cierre

- [ ] Los 6 grupos, etiquetas e íconos coinciden con
      [contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md).
- [ ] Cero regresiones de acceso por rol/plan (SC-004).
- [ ] Tema oscuro persistente, sin parpadeo, con *fallback* correcto sin storage (SC-002, SC-003).
- [ ] Colapso de escritorio persistente con tooltip accesible por teclado (FR-007, FR-017).
- [ ] Drawer móvil/tablet con scrim y cierre correcto (SC-005).
- [ ] Punto de quiebre reactivo en vivo, sin recargar (Edge Case).
- [ ] Lighthouse Accessibility = 100 en ambos temas (SC-006).
- [ ] Tema oscuro ampliado a tablas/formularios/tarjetas/gráficas de los ~18 módulos, sin mezclas
      de paleta (SC-007) — Terminal de Mesas incluida, tras su normalización.
- [ ] Reporte de caja y hoja de QR siempre en presentación clara, en pantalla y al imprimir
      (FR-010).
- [ ] Overlay de CDK de Promociones tematizado (FR-010).
- [ ] Barra de carga + skeleton + aparición escalonada en cada transición de navegación (SC-008).
- [ ] `prefers-reduced-motion` respetado, sin romper ninguna transición (SC-009).
- [ ] Scroll independiente del área de contenido (FR-015) intacto tras envolver el `router-outlet`
      en el contenedor de transición (Fase 9).
- [ ] El Sidebar/Navbar siguen resaltando el ítem padre en una subvista sin ítem propio, de forma
      genérica para cualquier módulo, sin confundir rutas que solo comparten prefijo de texto
      (FR-004 ampliado, p. ej. `/dashboard/mesas` vs. `/dashboard/mesas-sesiones`).
- [ ] Scrollbar del panel de tenant acorde al tema activo, en claro y en oscuro (FR-024, SC-011).
- [ ] Todos los `<select>` del panel de tenant son legibles en modo oscuro, incluyendo los que no
      tenían clases de color de Tailwind (FR-023, SC-010).
- [ ] El ícono del botón de menú/colapso es siempre `menu`, igual al archivo de diseño, en
      escritorio y en el menú móvil (FR-003).
- [ ] Los íconos sobre fondo pastel fijo (Mesas, Categorías, Ajustes del negocio, Productos sin
      imagen) son visibles en modo oscuro, sin fundirse con su contenedor (FR-025, SC-012).
- [ ] El panel de "adicionales" del modal de selección de producto en Terminal de Mesas se adapta
      al tema oscuro, sin fondo blanco fijo (FR-010).
- [ ] Super Admin, verificado visualmente, **sin ningún cambio** (R1).

## 18. Ícono de menú, íconos sobre fondo pastel y degradado de "adicionales" (FR-003, FR-025, FR-010) — nuevo, 2026-10-14

- Abrir el panel en escritorio y confirmar que el botón de menú/colapso muestra el ícono de
  hamburguesa (`menu`) tanto expandido como colapsado — nunca un ícono de panel/flechas.
- Con "Modo Oscuro" activo, visitar Mesas y Categorías y confirmar que el ícono dentro del
  recuadro violeta de cada fila es visible (no un cuadro violeta vacío).
- Con "Modo Oscuro" activo, visitar Ajustes del negocio (Configuración del tenant) y confirmar
  que los 5 íconos de encabezado de sección (paleta, recibo, impresora, tienda, persona) son
  visibles; visitar Productos (lista y detalle) y confirmar que el ícono de "sin imagen" también
  lo es.
- Con "Modo Oscuro" activo, desde Terminal de Mesas, armar un pedido, seleccionar un producto con
  adicionales y confirmar que el panel de opciones no tiene ningún fondo blanco fijo.

## 17. Resaltado por prefijo, scrollbar y `<select>` en oscuro (FR-004 ampliado, FR-023, FR-024) — nuevo, 2026-10-14

- Navegar a una subvista sin ítem propio en el Sidebar (p. ej. editar un ítem de Carta o
  Inventario) y confirmar que el Sidebar sigue resaltando el ítem padre y que el título/sección
  del Navbar siguen siendo los del módulo padre (FR-004).
- Navegar a "Terminal de Mesas" (`/dashboard/mesas-sesiones`) y confirmar que **no** se resalta
  "Mesas" (`/dashboard/mesas`) — las dos rutas comparten prefijo de texto pero son módulos
  distintos.
- Con "Modo Oscuro" activo, confirmar visualmente que el scrollbar del área de contenido principal
  (y de cualquier panel interno con scroll propio, p. ej. el Sidebar con 15 ítems) usa colores
  oscuros, no el scrollbar claro del navegador (FR-024, SC-011).
- Con "Modo Oscuro" activo, recorrer el selector de método de pago en Terminal de Mesas y los
  `<select>` de Inventario → "Registrar compra" (proveedor, presentación) y confirmar que todos
  son legibles — fondo y texto con contraste suficiente, ninguno con apariencia nativa clara
  (FR-023, SC-010).
