# Data Model: Bloqueo de la Traducción Automática y Aviso de Página Alterada

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Alcance del modelo

**No hay cambios en el modelo de datos del servidor**: ninguna tabla, columna, migración ni endpoint
nuevo en `pos-backend`; ningún pedido, factura ni histórico se lee o escribe distinto (Principio
VII/VIII: N/A). Todo lo que sigue es **estado transitorio del navegador**, vive en memoria
(señales de Angular) y desaparece al recargar. La única persistencia es una marca en
`sessionStorage` para el guardián anti-bucle.

## Estado en memoria

### `IntegrityState` — estado de integridad de la página

Entidad "Estado de integridad de la página" de la spec. Dueño: `PageIntegrityService`.

| Campo | Tipo | Descripción |
|---|---|---|
| `status` | `'intact' \| 'altered'` | lo que gobierna banner, bloqueo de acciones y momento seguro |
| `reasons` | `IntegritySignalId[]` | señales activas en la última evaluación (para pruebas y diagnóstico; no se muestra) |
| `latched` | `boolean` | `true` si alguna razón es S6 (error de DOM): no se limpia sin recargar |

`IntegritySignalId`: `'html-class'` (S1), `'html-lang'` (S2), `'font-wrapper'` (S3),
`'ms-translator-attr'` (S4), `'canary'` (S5), `'dom-error'` (S6). Definiciones en
[contracts/page-integrity.md](./contracts/page-integrity.md).

**Transiciones**

```text
intact ──(≥1 señal activa)──────────────────────────────▶ altered      inmediata
altered ──(señales no latched apagadas en 2 evaluaciones consecutivas, y latched=false)──▶ intact
altered ──(latched=true)── se mantiene hasta recargar la página
```

Estado inicial: resultado de la **primera evaluación**, hecha en el inicializador de la aplicación
(antes del primer pintado), de modo que una página ya alterada al cargar arranca como `altered`.

### `BlockedNotice` — acción bloqueada que se muestra al usuario

Dueño: `PageIntegrityService`. Una señal `string | null` con la etiqueta de la última acción
rechazada (p. ej. "enviar el pedido"). Se limpia cuando el estado vuelve a `intact`. Alimenta la
línea `role="alert"` del banner.

### `ProtectedAction` — acción protegida

Entidad "Acción protegida" de la spec. Es **configuración estática** (no estado): una constante
`PROTECTED_ACTIONS` en `core/integrity/protected-actions.ts`.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `string` | identificador estable (`QR-1`, `P-3`…) usado por las pruebas y el contrato |
| `method` | `'POST' \| 'PATCH' \| 'PUT' \| 'DELETE'` | método HTTP |
| `path` | `RegExp` | ruta **relativa a `environment.apiBaseUrl`**, sin query, anclada (`^…$`) |
| `label` | `string` | frase corta para el aviso, en infinitivo ("cobrar el pedido") |

Catálogo completo: [contracts/protected-actions.md](./contracts/protected-actions.md).

### `UpdateState` — versión nueva de la aplicación

Entidad "Versión de la aplicación (instalada y disponible)". Dueño: `AppUpdateService`.

| Campo | Tipo | Descripción |
|---|---|---|
| `pending` | `boolean` | hay una versión descargada (`VERSION_READY`) o el worker reportó `unrecoverable` |
| `lastCheckAt` | `number` (ms) | última `checkForUpdate()`; limita a una por 60 s |

### `UpdateBlocker` — bloqueador del momento seguro

Dueño: `UpdateGateService`. Registro `Map<string, () => boolean>`: cada entrada es un nombre y un
predicado que devuelve `true` mientras la pantalla **no** admite una recarga. Los bloqueadores se
registran en el constructor del dueño del estado y se retiran con `DestroyRef`.

| Nombre | Dueño | Predicado |
|---|---|---|
| `pos-terminal-draft` | `PosTerminalStore` (cubre también la orden manual, que usa su propia instancia) | `hasDraft()` |

El conteo de peticiones de escritura en vuelo también lo lleva `UpdateGateService`
(`beginRequest()`/`endRequest()`), alimentado por `inflightRequestsInterceptor`.

## Artefactos de documento (no estado)

| Elemento | Dónde | Valor |
|---|---|---|
| Idioma y bloqueo | `src/index.html` | `<html lang="es" translate="no" class="notranslate">` + `<meta name="google" content="notranslate">` |
| Canario | plantilla de `PageIntegrityBannerComponent` | `<span class="sr-only" aria-hidden="true" data-integrity-canary>` con una frase corta en español |
| Íconos | `IconMiComponent` | `translate="no"` y clase `notranslate` en el `<span class="material-icons-outlined">` |

## Almacenamiento del navegador

| Clave | Almacén | Contenido | Vida |
|---|---|---|---|
| `pos.update.autoReloadAt` | `sessionStorage` | epoch ms de la última recarga automática por versión | la pestaña; evita bucles (no recarga solo si hay una marca de < 2 min). Toda lectura/escritura envuelta en `try/catch` (almacenamiento bloqueado ⇒ se comporta como "sin marca") |

No se añade ninguna clave a `localStorage`. Las claves existentes que hacen posible la recuperación
tras recargar (`pos.diner.session_token`, tokens del personal) no cambian.
