# Feature Specification: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente

**Feature Branch**: `116-layout-base-panel-admin`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Implementar el layout base oficial (Sidebar + Navbar) del panel de administración y staff de SkeiloPOS, tomando como referencia el archivo de diseño `Layout base.dc.html`, unificando la navegación (reagrupada e iconografía) e incorporando un sistema de preferencia de tema claro/oscuro persistente en el navegador."

## Clarifications

### Session 2026-10-12

- Q: ¿El modo oscuro debe cubrir solo el marco del layout (sidebar/navbar/fondo del área de contenido) o también el contenido interno de cada módulo (tablas, formularios, gráficas)? → A: Solo el marco del layout; el contenido interno de cada módulo permanece en su apariencia clara actual y queda fuera de alcance de esta spec.
- Q: ¿Se reorganiza la navegación para igualar los 6 grupos del diseño de referencia, o se mantiene la agrupación actual? → A: Se adoptan los 6 grupos del diseño de referencia (Inicio, Operación, Catálogo, Inventario, Control, Administración), reubicando Reportes, Inventario, Proveedores y Caja respecto a la agrupación vigente.
- Q: ¿Se igualan también las etiquetas de texto exactas del diseño de referencia (por ejemplo, "Caja" → "Cajas")? → A: Sí, se igualan las etiquetas de texto del diseño de referencia.
- Q: ¿Qué punto de quiebre (breakpoint) usa el comportamiento responsive: el ya vigente en el panel o el que define el archivo de diseño? → A: Se mantiene el punto de quiebre ya vigente en el panel (pantallas menores a 1024px), no el del archivo de diseño.
- Q: ¿Los tokens visuales (tipografía, colores, espaciados, sombras) del diseño de referencia se aplican solo al layout base o a toda la aplicación? → A: Solo al layout base (sidebar, navbar y contenedor principal); no se extienden al contenido interno de los módulos existentes.
- Q: ¿Los íconos del sidebar/navbar deben igualar exactamente los del diseño de referencia o se conserva el set de íconos actual? → A: Se adopta el set de íconos del diseño de referencia.
- Q: ¿Esta spec aplica al panel aislado de Super Admin/plataforma? → A: No; aplica únicamente al panel de Administrador de Tenant / Cajero / Staff. El panel de Super Admin queda fuera de alcance.
- Q: ¿El estado de colapso del Sidebar en escritorio (expandido o reducido a solo íconos) debe recordarse entre recargas/sesiones igual que la preferencia de tema, o debe reiniciar siempre a expandido en cada carga del panel? → A: Persiste en el navegador, con el mismo mecanismo de almacenamiento y el mismo manejo de almacenamiento no disponible que la preferencia de tema.
- Q: Cuando el Sidebar está colapsado a solo íconos, ¿cómo deben identificar los usuarios cada ítem sin ver su etiqueta de texto? → A: Mediante un tooltip que muestra el nombre del ítem al pasar el mouse o dar foco de teclado sobre el ícono.
- Q: ¿Esta spec debe incluir un criterio de éxito medible de accesibilidad (contraste WCAG AA y puntuación mínima de accesibilidad) para el nuevo Sidebar/Navbar y el tema oscuro, o la accesibilidad se maneja sin una métrica explícita? → A: Sí, se agrega un criterio de éxito medible (contraste AA en ambos temas y una puntuación mínima de accesibilidad verificable), en línea con el estándar ya usado en specs previas del panel.
- Q: Tras la primera implementación se detectó que el diseño de referencia usado (`Layout base.dc.html`) estaba desactualizado frente al archivo completo de la app (`SkeiloPOS App.dc.html`, misma carpeta de diseños) — ¿se actualiza el layout para ser 100% fiel a este archivo más reciente, manteniendo sin cambios los estilos de animación/transición ya implementados? → A: Sí; `SkeiloPOS App.dc.html` pasa a ser la fuente de verdad visual del layout (sustituye a `Layout base.dc.html`); el ajuste es exclusivamente visual (estructura, colores, tipografía, iconografía, espaciados) — las transiciones/animaciones ya implementadas no se tocan.
- Q: El archivo de diseño actualizado usa el texto "Salir" para la acción de cerrar sesión; el panel (tanto el nuevo como el legado de Super Admin) usa hoy "Cerrar sesión" de forma consistente — ¿se adopta "Salir" o se mantiene "Cerrar sesión"? → A: Se mantiene "Cerrar sesión", por consistencia de vocabulario con el resto del panel de staff ("Salir" en el código solo se usa hoy en el menú QR del comensal, una audiencia distinta).
- Q: El archivo de diseño actualizado agrega un botón "Ayuda" al pie del Sidebar, pero el panel no tiene hoy ninguna pantalla, ruta o enlace de ayuda/soporte — ¿se agrega el botón sin una acción real detrás, o se omite? → A: Se omite; no existe destino real para ese botón y agregarlo sin acción sería UI muerta o alcance nuevo no solicitado (mismo criterio que ya aplicó esta spec para omitir la línea "Sede Laureles" por falta de datos reales).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Navegación y estructura visual del panel rediseñadas (Priority: P1)

Un administrador de tenant, cajero o miembro del staff abre el panel y necesita reconocer de inmediato dónde está cada módulo (Dashboard, Ventas, Órdenes, Mesas, Inventario, Reportes, Usuarios, etc.), con una apariencia moderna, limpia y consistente, y sin perder acceso a ningún módulo que ya tenía permitido por su rol o plan.

**Why this priority**: Es el valor central de la spec — sin la nueva estructura de navegación y la fidelidad visual, el resto de los requisitos (tema, responsive) no tienen marco donde aplicarse. Además, cualquier error aquí (un módulo mal ubicado o inaccesible) bloquea el trabajo diario de todo el panel.

**Independent Test**: Puede probarse iniciando sesión con distintos roles (administrador, cajero, staff) y verificando que el sidebar muestra los 6 grupos de navegación con sus etiquetas e íconos definidos, que el ítem activo se resalta al navegar, y que ningún módulo previamente accesible para ese rol/plan desapareció o cambió su guard de acceso.

**Acceptance Scenarios**:

1. **Given** que un usuario abre el panel de administración o staff, **When** la página termina de renderizar, **Then** el Sidebar y el Navbar se distribuyen según el diseño de referencia (tipografía, colores, espaciados y estructura de dos columnas), con la navegación agrupada en Inicio, Operación, Catálogo, Inventario, Control y Administración, usando las etiquetas e íconos definidos para cada ítem.
2. **Given** que el usuario navega por las opciones del Sidebar, **When** selecciona un módulo distinto (por ejemplo, Inventario, Ventas o Usuarios), **Then** el ítem seleccionado se resalta visualmente como activo y el contenido principal cambia a esa vista, manteniendo la estructura del layout.
3. **Given** un usuario cuyo rol o plan no tiene acceso a ciertos módulos, **When** abre el panel rediseñado, **Then** únicamente ve los grupos e ítems de navegación que ya tenía permitidos antes del rediseño — ningún ítem nuevo queda expuesto ni ninguno permitido antes se oculta o pierde su enlace/guard de acceso.
4. **Given** que el usuario colapsa el Sidebar a solo íconos y recarga la página, **When** el panel vuelve a cargar, **Then** el Sidebar se muestra colapsado igual como lo dejó, sin mostrar primero la versión expandida.

---

### User Story 2 - Alternar y conservar la preferencia de tema claro/oscuro (Priority: P2)

Un usuario del panel prefiere trabajar con un tema oscuro (por comodidad visual, por ejemplo en turnos nocturnos) y espera poder activarlo desde el propio panel, que esa preferencia se recuerde automáticamente la próxima vez que entre, y que el cambio no le haga perder de vista ni afecte el contenido de los módulos en los que trabaja.

**Why this priority**: Es un requisito explícito del negocio y mejora la experiencia diaria del usuario, pero depende de que la estructura del layout (User Story 1) ya exista para tener dónde aplicarse.

**Independent Test**: Puede probarse activando el interruptor de tema, confirmando el cambio inmediato de paleta en el sidebar/navbar/fondo, recargando la página y verificando que el tema oscuro persiste sin parpadeo del tema anterior.

**Acceptance Scenarios**:

1. **Given** que el usuario está en el panel con el tema claro (el valor por defecto cuando no hay preferencia guardada), **When** hace clic en el interruptor de tema para cambiar a "Modo Oscuro", **Then** el sidebar, el navbar y el fondo del área de contenido cambian de paleta de inmediato (el contenido interno de cada módulo permanece sin cambios) y la preferencia "oscuro" queda guardada en el navegador.
2. **Given** que el usuario configuró el "Modo Oscuro" y recarga la página, **When** el panel vuelve a cargar, **Then** se aplica el tema oscuro al marco del layout de inmediato, sin mostrar primero el tema claro por un instante.
3. **Given** que el usuario navega en un modo donde el navegador bloquea el almacenamiento local (por ejemplo, navegación privada), **When** abre o recarga el panel, **Then** el panel carga normalmente con un tema por defecto (claro, o el de preferencia del sistema operativo si está disponible), sin mostrar errores ni quedar en un estado roto.

---

### User Story 3 - Uso cómodo del panel en pantallas pequeñas (Priority: P3)

Un miembro del staff o un cajero que usa una tablet o un celular para operar el panel necesita que el sidebar no le quite espacio útil de la pantalla, pudiendo abrirlo solo cuando lo necesita.

**Why this priority**: Mejora la usabilidad en dispositivos pequeños, pero el panel ya es parcialmente usable sin este comportamiento específico (es un refinamiento sobre la base de las dos historias anteriores).

**Independent Test**: Puede probarse abriendo el panel en una ventana o dispositivo con un ancho menor a 1024px y verificando que el sidebar se oculta por defecto, es accesible mediante un botón de menú, y se cierra solo o mediante un fondo oscurecido (scrim) al tocar fuera de él.

**Acceptance Scenarios**:

1. **Given** que el usuario abre el panel en un dispositivo o ventana con ancho menor a 1024px, **When** visualiza el layout, **Then** el Sidebar se oculta automáticamente y se transforma en un menú desplegable (accesible mediante un botón de menú/hamburguesa), y el área de contenido aprovecha el 100% del ancho disponible.
2. **Given** que el sidebar está abierto como menú desplegable en pantalla pequeña, **When** el usuario selecciona un módulo o toca fuera del menú, **Then** el menú se cierra automáticamente y el usuario queda viendo el contenido del módulo seleccionado (o el mismo contenido que tenía, si solo cerró el menú).

---

### Edge Cases

- ¿Qué pasa si un grupo de navegación queda sin ningún ítem visible para el rol/plan del usuario actual (todos sus ítems están restringidos)? El grupo completo no debe mostrarse vacío en el sidebar.
- ¿Qué pasa si el nombre del tenant o de la sede es muy largo? Debe truncarse de forma legible en el encabezado del sidebar, sin romper el diseño.
- ¿Qué pasa si el usuario cambia el tamaño de la ventana del navegador en vivo, cruzando el punto de quiebre de 1024px mientras el panel está abierto? El layout debe adaptarse (colapsar/expandir el sidebar) sin recargar la página ni perder el módulo que estaba viendo.
- ¿Qué pasa si el usuario cambia la preferencia de tema del sistema operativo mientras tiene una preferencia explícita ya guardada en el panel? La preferencia explícita guardada en el panel prevalece sobre la del sistema.
- ¿Qué pasa si el usuario abre el panel por primera vez en un dispositivo donde el sistema operativo está configurado en modo oscuro? Sin una preferencia previa guardada en el panel, se usa esa señal del sistema como mejor aproximación antes de aplicar el tema claro por defecto.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE presentar el Sidebar y el Navbar del panel siguiendo la tipografía, paleta de colores, espaciados y estructura de dos columnas definidos en el diseño de referencia oficial.
- **FR-002**: El sistema DEBE agrupar la navegación del sidebar en seis categorías — Inicio, Operación, Catálogo, Inventario, Control y Administración — con los ítems y etiquetas de texto definidos en el diseño de referencia (incluyendo el renombre del módulo de caja a su forma plural).
- **FR-003**: El sistema DEBE usar la iconografía definida en el diseño de referencia para cada ítem de navegación del sidebar y para los controles del navbar (menú, notificaciones, tema, usuario).
- **FR-004**: El sistema DEBE resaltar visualmente el ítem de navegación correspondiente a la vista actualmente activa.
- **FR-005**: El sistema DEBE preservar exactamente la lógica de visibilidad por rol y por plan que ya existe hoy para cada módulo de navegación — el rediseño NO DEBE otorgar acceso a un módulo antes restringido ni ocultar/romper el acceso a uno antes permitido.
- **FR-006**: El sistema DEBE preservar todas las rutas, enlaces y validaciones de acceso (guards) existentes del panel; el rediseño es exclusivamente visual y de organización de la navegación.
- **FR-007**: El sistema DEBE permitir colapsar el Sidebar a una versión reducida (solo íconos) en pantallas de escritorio, y expandirlo de nuevo, sin perder la vista actual. Mientras está colapsado, el sistema DEBE mostrar un tooltip con el nombre del ítem al pasar el mouse o dar foco de teclado sobre su ícono.
- **FR-008**: El sistema DEBE ocultar el Sidebar por defecto en pantallas con ancho menor a 1024px, haciéndolo accesible mediante un control de menú/hamburguesa que lo despliega como panel superpuesto con un fondo oscurecido (scrim) de fondo.
- **FR-009**: El sistema DEBE ofrecer un control en el Navbar para alternar entre tema claro y tema oscuro.
- **FR-010**: El sistema DEBE aplicar el cambio de tema únicamente al marco del layout — Sidebar, Navbar y fondo del área de contenido — sin alterar la apariencia del contenido interno de los módulos existentes.
- **FR-011**: El sistema DEBE recordar la preferencia de tema elegida por el usuario en el navegador, de forma que persista entre recargas de página y entre sesiones de navegación en el mismo navegador.
- **FR-012**: El sistema DEBE aplicar el tema guardado (o el tema por defecto) antes de que el contenido visible del panel termine de pintarse, evitando que se muestre brevemente un tema distinto al que corresponde.
- **FR-013**: Cuando no exista una preferencia de tema guardada, el sistema DEBE usar el tema claro por defecto, salvo que pueda detectar una preferencia de tema oscuro del sistema operativo del usuario, en cuyo caso DEBE usar esa señal como aproximación inicial.
- **FR-014**: El sistema DEBE seguir funcionando con normalidad, sin mostrar errores al usuario ni en la consola del navegador, cuando el almacenamiento local del navegador no esté disponible (por ejemplo, en navegación privada) — en ese caso, DEBE usar el tema por defecto en cada carga, sin persistir la preferencia.
- **FR-015**: El sistema DEBE mantener el área de contenido principal con desplazamiento (scroll) independiente del Sidebar y del Navbar.
- **FR-016**: El sistema NO DEBE mostrar vacío ningún grupo de navegación cuyos ítems estén completamente restringidos para el rol/plan del usuario actual — el grupo completo debe omitirse en ese caso.
- **FR-017**: El sistema DEBE recordar el estado de colapso/expansión del Sidebar en pantallas de escritorio en el navegador, con el mismo mecanismo de persistencia y el mismo manejo de almacenamiento no disponible que la preferencia de tema (FR-011, FR-014), de forma que el estado elegido se mantenga entre recargas de página y entre sesiones de navegación en el mismo navegador; cuando no exista un estado guardado o el almacenamiento no esté disponible, el Sidebar inicia expandido por defecto.

### Key Entities

- **Preferencia de tema**: Valor (claro u oscuro) elegido por el usuario para el marco del panel; se guarda en el navegador y se recupera en cada carga del panel; si no existe, se deriva de la preferencia de tema del sistema operativo o, en su defecto, del tema claro.
- **Ítem de navegación**: Representa un módulo accesible desde el Sidebar (por ejemplo, "Ventas" o "Inventario"); tiene un grupo al que pertenece, una etiqueta visible, un ícono y una visibilidad determinada por el rol y el plan del usuario actual — esta visibilidad ya existe hoy y no cambia con esta spec.
- **Preferencia de colapso del Sidebar**: Valor (expandido o colapsado a solo íconos) elegido por el usuario para el Sidebar en pantallas de escritorio; se guarda en el navegador con el mismo mecanismo que la preferencia de tema y se recupera en cada carga del panel; si no existe o el almacenamiento no está disponible, se usa expandido por defecto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los usuarios que abren el panel ven el Sidebar y el Navbar distribuidos según el diseño de referencia (agrupación de seis categorías, etiquetas e iconografía correctas), verificable con una inspección visual directa.
- **SC-002**: El 100% de los usuarios que cambian el tema a oscuro y recargan la página vuelven a ver el tema oscuro aplicado al marco del layout, sin percibir un parpadeo del tema contrario.
- **SC-003**: El 100% de las sesiones en navegación privada (u otro escenario sin almacenamiento disponible) cargan el panel sin errores visibles ni errores registrados en la consola del navegador.
- **SC-004**: El 100% de los usuarios conservan, después del rediseño, el acceso exacto a los mismos módulos que tenían antes según su rol y plan — cero regresiones de acceso reportadas.
- **SC-005**: En pantallas con ancho menor a 1024px, el 100% de los usuarios pueden acceder a cualquier módulo permitido para su rol a través del menú desplegable, sin que el Sidebar reduzca el espacio disponible para el contenido mientras está cerrado.
- **SC-006**: El Sidebar, el Navbar y el fondo del área de contenido cumplen un contraste de color conforme a WCAG 2.1 AA tanto en tema claro como en tema oscuro, y obtienen una puntuación de accesibilidad (Lighthouse) de 100, verificable mediante auditoría automatizada.

## Assumptions

- Esta spec cubre el panel de Administrador de Tenant, Cajero y Staff (el layout con Sidebar y Navbar ya existente en el panel); el panel aislado de Super Admin/plataforma queda fuera de alcance.
- El cambio de tema afecta únicamente el marco del layout (Sidebar, Navbar, fondo del área de contenido); el contenido interno de cada módulo (tablas, formularios, gráficas de Ventas, Inventario, Reportes, etc.) conserva su apariencia actual y se tematizará, si se decide, en una spec futura.
- La paleta, tipografía, espaciados y radios de borde del diseño de referencia se incorporan como un conjunto de estilos acotado al marco del layout, sin reemplazar los estilos ya usados en el resto de las pantallas y módulos del panel.
- El punto de quiebre responsive (ancho menor a 1024px activa el comportamiento de menú desplegable) es el ya vigente en el panel; no se adopta ningún otro umbral distinto del diseño de referencia.
- La reagrupación y el renombre de ítems de navegación (seis grupos, etiquetas del diseño de referencia) es un cambio de organización visual de la navegación existente, no un cambio en qué módulos existen ni en quién puede acceder a ellos.
- Las acciones del menú de usuario (cambiar contraseña, ver plan, cerrar sesión) y el indicador de estado de caja ya existen como funcionalidades del panel; esta spec solo cubre su presentación dentro del nuevo Navbar, no cambios en su comportamiento. El texto de cada acción es el que ya usa el panel hoy (p. ej. "Cerrar sesión") — el diseño de referencia no reemplaza textos ya establecidos y consistentes en el panel de staff.
- El diseño de referencia (`SkeiloPOS App.dc.html`, carpeta de diseños — sustituye a `Layout base.dc.html`, desactualizado) se usa como fuente de verdad visual (estructura, tipografía, colores, iconografía, espaciados), no como código a reproducir literalmente, dado que está escrito en una herramienta de prototipado distinta a la base tecnológica real del panel; las transiciones/animaciones ya implementadas no se tocan en este ajuste.
- Los elementos del diseño de referencia sin una funcionalidad real detrás en el panel (p. ej. un botón "Ayuda" sin pantalla, ruta ni enlace de soporte existente) se omiten, con el mismo criterio ya aplicado a la omisión de la segunda línea "Sede Laureles" por falta de datos reales.
