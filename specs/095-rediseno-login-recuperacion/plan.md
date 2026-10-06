# Implementation Plan: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Branch**: la spec vive en `specs/095-rediseno-login-recuperacion/` de `pos-specs`, rama `main`. La rama de código es `style/095-auth-screens-redesign` en `pos-heladeria`, y **solo ahí** (Principio XIV) | **Date**: 2026-10-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/095-rediseno-login-recuperacion/spec.md`

## Summary

Las tres pantallas de autenticación de SkeiloPOS —entrar, pedir un enlace, crear la contraseña
nueva— hoy no se parecen entre sí: el login tiene dos columnas y un panel decorativo, las otras
dos son tarjetas centradas sin etiqueta, sin pie y sin marca. Esta spec las convierte en **un
solo sistema**, sin tocar una línea del servidor.

El enfoque técnico tiene un centro de gravedad: **un cascarón compartido**.
`AuthShellComponent` pone la rejilla de dos columnas, el logotipo, la etiqueta de contexto, el
pie y el panel de marca; cada pantalla aporta únicamente su formulario. Eso convierte FR-001 y
FR-002 en una propiedad estructural en vez de una coincidencia que se rompe en el primer
arreglo, y concentra en un archivo —con sus tests— los requisitos transversales: el pie
(FR-003), el panel que no descarga su imagen en móvil (FR-005), la etiqueta que se resuelve sin
preguntarle a nadie (FR-007 a FR-008) y el aviso de host no reconocido (FR-009).

Alrededor de ese centro, el trabajo es casi todo reuso de lo que ya existe:
`TenantContextService` de la spec 091 resuelve el contexto de forma síncrona en el arranque —que
es exactamente lo que FR-007a y FR-007c piden—, `PasswordInputComponent` ya tiene el ojo con su
`aria-pressed`, `AuthService` ya habla con los cuatro endpoints, y el interceptor ya pone
`X-Tenant-Host` en las peticiones no autenticadas. **Cero dependencias nuevas, cero endpoints,
cero migraciones, cero cambios en `pos-backend`.**

Lo que el reconocimiento añadió al pedido son **tres hallazgos** que el plan tiene que resolver,
y uno de ellos no se puede resolver aquí:

1. **El 403 filtra que la cuenta existe** (R7). Una cuenta desactivada hoy ve
   *"User account is inactive"*, en inglés, mientras una inexistente ve otro texto. FR-012 y
   SC-003 lo cierran mapeando 401 y 403 al mismo literal, en el camino del login.
2. **El ojo de la contraseña es inalcanzable por teclado** (R9): `tabindex="-1"` incumple
   FR-040 y WCAG 2.1.1. Se quita en el componente compartido, que es donde vive el problema.
3. **FR-037 no es implementable en este alcance** (R18). El enlace de recuperación se resuelve
   solo por el hash del token, sin mirar el host, así que un enlace de un negocio abierto en el
   subdominio de otro **funciona**. Cerrarlo exige modificar dos endpoints, que es justo lo que
   FR-044 prohíbe. **Resuelto el 2026-10-05 por D13**: se acepta la limitación, FR-044 prevalece y
   FR-037 pasa a ser limitación documentada en A-111 — ver
   [Puertas que necesitan decisión](#puertas-que-necesitan-decisión).

## Technical Context

**Language/Version**: TypeScript 5.9 con Angular 21.1 en `pos-heladeria` — componentes
standalone, signals, control de flujo `@if`/`@switch`, `ChangeDetectionStrategy.OnPush` donde
aplique. **`pos-backend` no participa**: Python y FastAPI quedan fuera del alcance por FR-044.

**Primary Dependencies**: `@angular/core` 21.1, `@angular/forms` (Reactive Forms) y Tailwind CSS
4.1. **Ninguna dependencia nueva** (Principio IX satisfecho por ausencia): la cuenta regresiva
es `setInterval` + `Date.now()`, el bloqueo es `sessionStorage`, los íconos ya están en
`ICON_CATALOG` (`check`, `circle`, `storefront`, `admin_panel_settings`), y la auditoría WCAG se
hace con Lighthouse, que ya
viene en el navegador (R15).

**Storage**: ninguno persistente. **No hay esquema, ni migración, ni rollback de datos.** Lo
único que se escribe en el navegador es una clave de `sessionStorage` con el instante de
vencimiento del bloqueo de reenvío — un número, sin dato personal, que caduca al cerrar la
pestaña (R10, [data-model.md](./data-model.md) §3).

**Testing**: Vitest 4 + `TestBed` vía `npm test`, con un `*.component.spec.ts` hermano por
componente, siguiendo el patrón de `login.component.spec.ts` (contexto de tenant simulado con un
doble de `TenantContextService`). `forgot-password` y `reset-password` **hoy no tienen tests**
(R17) y los ganan, porque son el único lugar donde FR-020 a FR-034 se pueden verificar. Los
characterization tests de autenticación viven en `pos-backend` y esta spec no los puede afectar,
porque no toca nada de lo que cubren.

**Target Platform**: navegador en tres formatos reales de uso — escritorio del mostrador,
tableta y celular del negocio—, desde 360 px hasta 1920 px, en tema claro y en español
únicamente (_Assumptions_ de la spec). Las pantallas son públicas: se sirven **antes** de
cualquier sesión, en `<slug>.skeilopos.com`, `admin.skeilopos.com` o un host no reconocido.

**Project Type**: aplicación web, pero **de un solo lado**: frontend Angular. Es la primera spec
reciente que no toca el backend, y eso es una decisión de negocio ya tomada (D2), no una
omisión.

**Performance Goals**:
- La pantalla se completa **sin esperar ninguna petición** (SC-011): la etiqueta sale del
  contexto resuelto en el arranque, no de la red.
- Por debajo de 1024 px, la vista previa del panel **no se descarga** (FR-005, SC-007). No es un
  objetivo cosmético: es la diferencia entre ~70 KB y 0 KB en la pantalla que más se abre desde
  el celular del negocio.
- El presupuesto del activo de vista previa es **≤ 80 KB** en WebP (R2).

**Constraints**:
- **FR-044 es inviolable**: ni un endpoint nuevo, ni uno modificado. `git status` de
  `pos-backend` tiene que quedar limpio.
- **Un fallo de autenticación, un solo mensaje** (FR-012, SC-003): correo inexistente,
  contraseña incorrecta y cuenta desactivada son indistinguibles.
- **Nada se expone sin autenticar** (FR-007b): la pantalla se construye solo con lo que el
  subdominio ya revela.
- **El control "Mantener sesión iniciada" está obligado a no hacer nada** (FR-019b a FR-019e):
  no viaja al servidor, no cambia la vida de la sesión, no guarda contraseñas y su texto no
  promete lo contrario.
- **La etiqueta se muestra sin transformar** (FR-007): el slug tal cual, lo que se cumple no
  haciendo nada.
- **Los literales de los textos los fija la spec**, no se parafrasean — por eso tienen contrato
  propio: [contracts/auth-copy-contract.md](./contracts/auth-copy-contract.md).
- **Una sola fuente para la política de contraseñas** (FR-027, FR-029): la lista visible y los
  validadores salen del mismo módulo, o terminan discrepando.

**Scale/Scope**: 3 pantallas rediseñadas + 1 cascarón nuevo + 1 módulo de política + 1 servicio
de aviso + 1 campo de configuración + 1 activo de imagen. Aproximadamente **8 archivos de
producción y 4 de test** en `pos-heladeria`, 1 archivo eliminado (`login-panel.svg`), y 2
expectativas de texto actualizadas en un test existente. **Cero archivos en `pos-backend`.**

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Evidencia |
|-----------|--------|-----------|
| **I** — Las nuevas funcionalidades nacen de un spec | ✅ PASA | `spec.md` con 4 historias, 57 FR, 13 SC, 13 decisiones documentadas (D1–D12 más la sub-decisión D3a) y sesión de clarificación cerrada. Sin `NEEDS CLARIFICATION` pendientes. |
| **II** — El comportamiento existente sigue protegido | ⚠️ **PASA CON CONDICIÓN** | Cuatro comportamientos existentes cambian, los cuatro exigidos por la spec: el mensaje de credenciales (FR-012), los dos textos de la spec 091 (D7, D8), el destino del éxito del reset (FR-031) y el alcance del aviso de host no reconocido (FR-009 en las tres pantallas). Exigen las entradas **A-108, A-109 y A-110** en `registro-de-anomalias.md` **antes** de implementar. A esas tres se suma una cuarta, **A-111**, el hallazgo de FR-037 (R18), ya resuelto por D13. La condición que queda es puramente de ejecución: escribir las cuatro entradas antes de tocar código (puerta G1). |
| **III** — Los characterization tests protegen el comportamiento heredado | ✅ PASA | Ningún test `"CONGELA comportamiento actual:"` se toca. Verificado que **no existe ninguno** en el área de autenticación del frontend (R17); los del backend (`test_auth_forgot_password.py`, `test_auth_reset_password.py`, `test_auth_login_platform_isolation.py`) quedan intactos porque el backend no cambia. Los dos tests que sí cambian son de la spec 091, sin prefijo `CONGELA`, y solo en sus literales (R16). |
| **IV** — Los nuevos specs pueden introducir nuevo comportamiento | ✅ PASA | El cascarón, la etiqueta unificada, el bloqueo de reenvío, la lista de requisitos y el control inerte son comportamiento nuevo autorizado por FR-001 a FR-043. |
| **V** — Nuevas funcionalidades antes que refactorizaciones oportunistas | ✅ PASA | Se evaluaron y **descartaron** tres refactorizaciones tentadoras: agrupar las tres rutas bajo un componente de ruta padre (R1), cambiar el primario del sistema a violeta (R3) y adoptar las tipografías del mockup (R4). Los dos cambios en código compartido están forzados por una FR y son mínimos: quitar un `tabindex="-1"` que incumple FR-040 (R9) y añadir un método `focus()` aditivo que FR-013 necesita (R8). |
| **VI** — Evolución incremental | ✅ PASA | Un solo repositorio, una sola clase de cambio (presentación), cuatro unidades verificables e independientes: cascarón → login → solicitud → contraseña nueva. Nada de migración, arquitectura ni datos mezclado. Se rechazó explícitamente meter el arreglo del backend de FR-037 en este incremento (R18). |
| **VII** — Compatibilidad con datos históricos | ✅ N/A | No se lee ni se escribe ningún dato de negocio. Ninguna factura se toca, ni directa ni indirectamente. |
| **VIII** — Evolución del modelo de datos | ✅ N/A | No hay modelo de datos que evolucionar: ni entidad, ni campo, ni relación, ni migración ([data-model.md](./data-model.md) §0). El rollback es revertir commits de frontend. |
| **IX** — Dependencias nuevas permitidas con justificación | ✅ PASA | **Ninguna dependencia nueva.** Se evaluó `axe-core`/`jest-axe` para SC-005 y se descartó: tres pantallas auditadas una vez no justifican una dependencia permanente cuando Lighthouse ya está en el navegador (R15). |
| **X** — Verificación obligatoria | ✅ PASA | Tests nuevos para el cascarón y las dos pantallas que hoy no tienen; tests ampliados en login; recorrido manual completo en [quickstart.md](./quickstart.md) para lo que un test de DOM no puede ver (foco real, teclado, descargas de red, responsive, lector de pantalla); auditoría WCAG para SC-005. |
| **XI** — Decisiones de negocio frente a decisiones técnicas | ✅ PASA | Las decisiones técnicas están en [research.md](./research.md) (R1 a R20) y las de negocio en la spec (D1 a D13). **FR-037 vs FR-044 era un conflicto entre dos requisitos de la misma spec**, y resolverlo era una decisión de negocio, no técnica: el plan no la tomó, la documentó y la escaló, y quedó resuelta en **D13** el 2026-10-05 a favor de FR-044. |
| **XII** — Trazabilidad | ✅ PASA | Cada FR tiene su decisión en research, su contrato y su paso de verificación. Los tres hallazgos del reconocimiento tienen entrada propia en el registro de anomalías con su evidencia en código, archivo y línea. |
| **XIII** — Todo en Español de Colombia | ✅ PASA | Todos los artefactos de esta spec en español de Colombia. Los textos de interfaz también, en tratamiento de "tú" como las pantallas actuales. |
| **XIV** — Estrategia y convención de ramas Git | ✅ PASA | `style/095-auth-screens-redesign` en `pos-heladeria`, creada **antes** de tocar código. `style` es el tipo correcto: es un rediseño de superficie. `pos-backend` no necesita rama porque no cambia. |
| **XV** — Política de commits Git | ✅ PASA | Commits pequeños por unidad (cascarón, login, solicitud, contraseña nueva, componente compartido, configuración, activos), en inglés, Conventional Commits, sin marcas de asistencia de IA, y **solo cuando el usuario los pida**. |

### Puertas que necesitan decisión

**G2 quedó cerrada el 2026-10-05. Solo queda G1, que es trabajo de documentación previo al código.**

| # | Puerta | Qué hace falta | Bloquea |
|---|---|---|---|
| **G1** | **A-108, A-109 y A-110** registradas en `specs/000-reconocimiento/registro-de-anomalias.md` | Escribir las tres entradas con qué cambia, por qué, quién decidió y qué afecta (Principio II). Las decisiones ya están tomadas en la spec: solo hay que asentarlas | Empezar a implementar los cambios de texto y de flujo |
| **G2** | ✅ **CERRADA — A-111 resuelta por D13** | Decidido el 2026-10-05 por Leonardo Gómez: se acepta la limitación, FR-044 prevalece y FR-037 se reformula como limitación documentada (opción **(a)** de las dos que el plan planteó). Queda por hacer: asentar la decisión en A-111 junto con el resultado observado de T059 (T064) | Nada. La spec puede declararse completa |

El trabajo de las cuatro unidades de implementación nunca dependió de G2: FR-037 no añade ni quita
una línea de frontend. Con G2 cerrada, lo único que precede al código es G1.

## Project Structure

### Documentation (this feature)

```text
specs/095-rediseno-login-recuperacion/
├── plan.md                           # Este archivo
├── spec.md                           # Contrato funcional (ya existía)
├── research.md                       # Fase 0: R1 a R20, con los tres hallazgos
├── data-model.md                     # Fase 1: estructuras de cliente (no hay modelo persistido)
├── quickstart.md                     # Fase 1: guía de validación en 11 pasos
├── contracts/
│   ├── auth-shell-contract.md        # Cascarón + estructura observable de las tres pantallas
│   └── auth-copy-contract.md         # Literales, con su origen y lo que está prohibido escribir
├── checklists/                       # Ya existía
└── tasks.md                          # Fase 2 — lo genera /speckit-tasks, no este comando
```

### Source Code (repositorio `pos-heladeria`)

```text
pos-heladeria/
├── src/
│   ├── app/
│   │   ├── modules/auth/
│   │   │   ├── components/
│   │   │   │   ├── auth-shell.component.ts          # NUEVO — cascarón (FR-001 a FR-010)
│   │   │   │   └── auth-shell.component.spec.ts     # NUEVO
│   │   │   ├── pages/
│   │   │   │   ├── login.component.ts               # REESCRITO (presentación) + FR-012/013/019a-e
│   │   │   │   ├── login.component.spec.ts          # AMPLIADO + 2 literales de D7/D8
│   │   │   │   ├── forgot-password.component.ts     # REESCRITO + bloqueo de reenvío
│   │   │   │   ├── forgot-password.component.spec.ts# NUEVO (hoy no existe)
│   │   │   │   ├── reset-password.component.ts      # REESCRITO + lista de requisitos
│   │   │   │   ├── reset-password.component.spec.ts # NUEVO (hoy no existe)
│   │   │   │   └── change-password.component.ts     # NO SE TOCA (D10)
│   │   │   └── password-policy.ts                   # NUEVO — fuente única de la política (R13)
│   │   ├── core/
│   │   │   ├── auth/auth-notice.service.ts          # NUEVO — aviso de un solo uso (FR-031, R12)
│   │   │   ├── services/auth.service.ts             # MODIFICADO — mapeo 401/403 del login (R7)
│   │   │   └── tenant/app-environment.interface.ts  # MODIFICADO — campo publicSiteUrl (R14)
│   │   └── shared/password-input/
│   │       └── password-input.component.ts          # MODIFICADO — sin tabindex="-1" (R9) + focus() (R8)
│   ├── environments/
│   │   ├── environment.ts                           # MODIFICADO — publicSiteUrl
│   │   └── environment.development.ts               # MODIFICADO — publicSiteUrl
│   └── styles.css                                   # MODIFICADO — fondo del panel tras @media (R2)
└── public/images/
    ├── auth-preview.webp                            # NUEVO — vista previa, ≤ 80 KB
    └── login-panel.svg                              # ELIMINADO — no es una vista previa (R2)
```

**`pos-backend/`**: sin cambios. FR-044.

**Structure Decision**: se respeta la estructura existente de `pos-heladeria` sin inventar
carpetas. El cascarón va en `modules/auth/components/` porque es de uso exclusivo de las tres
pantallas de autenticación y no tiene nada que hacer en `shared/`; la política va en
`modules/auth/` por la misma razón. Lo que sí entra en `core/` es `AuthNoticeService`, porque
cruza una frontera de ruta (lo fija reset, lo lee login) y `core/auth/` es donde ya viven
`auth-api.service.ts` y `token-storage.service.ts`. Los dos archivos compartidos que se tocan
—`password-input.component.ts` y `app-environment.interface.ts`— se modifican donde están, con
cambios mínimos y justificados por una FR cada uno.

### Orden de implementación sugerido (unidades verificables, Principio VI)

| Unidad | Qué entrega | Por qué en este orden |
|---|---|---|
| **0** | Las entradas A-108 a A-111 del registro de anomalías | El Principio II lo exige **antes** de implementar (puerta G1) |
| **1** | `publicSiteUrl`, el activo WebP, el estilo del panel, y el cascarón con sus tests | Nada más se puede montar sin él; se prueba solo, con los tres contextos de host |
| **2** | Login: cascarón, control inerte, FR-012, FR-013, FR-015 y el ojo alcanzable | La pantalla P1: si algo se rompe aquí, nadie trabaja |
| **3** | Solicitud de enlace: cascarón, mensaje genérico, bloqueo de reenvío, mensaje de 429 | Independiente de la 4; cierra la Historia 2 |
| **4** | Contraseña nueva: cascarón, módulo de política, lista accesible, estado único de enlace inválido, aviso a `/login` | Cierra la Historia 3 y consume el servicio de aviso que esta unidad introduce |
| **5** | Recorrido manual completo y auditoría WCAG | Lo que los tests no ven; cierra la Historia 4 y SC-004 a SC-007 |

## Complexity Tracking

> Se llena solo cuando el Constitution Check tiene violaciones que haya que justificar. Aquí no
> hay violaciones, pero sí dos cambios en código compartido y un requisito no entregable, y
> dejarlos sin explicación sería peor que registrarlos.

| Punto | Por qué es necesario | Alternativa más simple, y por qué se rechazó |
|-------|----------------------|----------------------------------------------|
| Quitar `tabindex="-1"` del `PasswordInputComponent` compartido, que afecta a 3 pantallas fuera del alcance | FR-040 exige que **todos** los controles se activen con teclado, y el control vive en el componente compartido. Hoy incumple WCAG 2.1.1 en las 5 pantallas que lo usan | Un `@Input()` para hacerlo enfocable solo en autenticación: rechazado porque dejaría el acceso por teclado deliberadamente roto en las otras tres pantallas a cambio de una opción que nadie pondría en `false` (R9) |
| Añadir `focus()` al mismo componente compartido | FR-013 exige mover el foco al campo de contraseña tras un fallo, y el `<input>` real vive dentro del hijo | `document.getElementById('password')?.focus()`: funciona, pero deja el contrato en una cadena de texto que un cambio de `id` rompe en silencio (R8) |
| **FR-037 se entrega como hallazgo documentado, no como código** | El token se resuelve solo por su hash, sin mirar el host (`routes.py:68-94`), y la respuesta de validación no dice a qué negocio pertenece. Cerrarlo exige modificar dos endpoints, que **FR-044 prohíbe en la misma spec** | Tocar el backend aquí: rechazado por FR-044, por la asunción "Alcance por repositorio" de la spec y por el Principio VI (mezclaría un rediseño de superficie con un cambio de contrato de autenticación). Queda como A-111. **D13 (2026-10-05) aceptó la limitación**, y no abre spec de backend (R18) |

## Constitution Check — re-evaluación posterior al diseño

Repasado el diseño completo de la Fase 1 (cascarón, estructuras de cliente, contratos y guía de
validación), **el resultado no cambia**: catorce principios en verde, uno en "pasa con condición"
—el Principio II, a la espera de que se escriban las cuatro entradas del registro— y ninguna
violación. El Principio XI pasó a verde el 2026-10-05, cuando D13 resolvió el conflicto
FR-037 / FR-044 que el plan había escalado. El diseño, de hecho, mejoró el cumplimiento en tres puntos concretos:

- **Principio V**: el cascarón redujo la superficie de cambio en vez de ampliarla. Tres
  requisitos transversales (pie, panel, etiqueta) que habrían obligado a tocar tres plantillas
  se resuelven en un archivo.
- **Principio IX**: el diseño cerró la única tentación de dependencia nueva. La cuenta regresiva
  resistente a timers estrangulados salió de dos restas de `Date.now()` (R10) y la auditoría de
  accesibilidad, de una herramienta que ya está instalada (R15).
- **Principio X**: la Fase 1 convirtió en verificable lo que la spec dejaba como intención.
  FR-005 pasó de "no mostrar la imagen" a "comprobar en la pestaña Red que el archivo no
  aparece"; FR-022, de "cuenta regresiva real" a "70 segundos en segundo plano y vuelve
  habilitado"; FR-012, de "el mismo mensaje" a "idéntico carácter por carácter en los tres
  casos, incluida la cuenta desactivada".

De las dos condiciones originales queda una: **G1**, el trabajo de documentación que hay que hacer
antes de empezar. **G2** —la decisión del negocio sobre el conflicto interno de la propia spec— se
cerró el 2026-10-05 con D13.

---

**Artefactos generados**: [research.md](./research.md), [data-model.md](./data-model.md),
[quickstart.md](./quickstart.md),
[contracts/auth-shell-contract.md](./contracts/auth-shell-contract.md),
[contracts/auth-copy-contract.md](./contracts/auth-copy-contract.md).

**Siguiente paso**: `/speckit-tasks` para generar `tasks.md`. La unidad 0 (registro de
anomalías) debe quedar como primera tarea, bloqueante.
