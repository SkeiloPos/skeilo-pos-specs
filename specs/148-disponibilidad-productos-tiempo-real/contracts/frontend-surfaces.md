# Contrato: superficies del cliente y su comportamiento

**Spec**: [../spec.md](../spec.md) (FR-003, FR-012 a FR-020, FR-025 a FR-029) | **Research**: [../research.md](../research.md) (D10 a D15)

Matriz de **qué hace cada pantalla** ante un cambio de disponibilidad. Las filas marcadas ★ son las
que las specs de cobro suelen olvidar.

## Dónde vive la sincronización

| Público | Arranca | Fuente de datos que se parcha | Snapshot |
|---|---|---|---|
| Personal | `DashboardLayoutComponent` (junto a `connectStaff()`) | `MenuService.categories` (compartido por Terminal, orden manual, drawer) | `GET /menu/availability` |
| Comensal | `DinerShellComponent` (junto a `connectDiner()`) ★ | índice de `DiningCartService` (raíz) **y**, mientras exista, el signal `categories` de `PublicMenuComponent` | `GET /menu/qr-token/{token}/availability` |

★ El comensal **no** puede depender de `PublicMenuComponent`: los pasos de pago son rutas hermanas
y se destruye al navegar (precedente spec 077, `diner-shell.component.ts`).

## Regla de presentación compartida

`isProductSoldOut(p) = p.sold_out || p.available === false` — misma etiqueta «Agotado» y misma
selección deshabilitada para marca manual y para inventario (FR-012). Presentaciones y opciones ya
usan `available === false`.

## Matriz por superficie

| # | Superficie | Cambio de disponibilidad en vivo | Carrito / borrador | Envío | Indicador de conexión |
|---|---|---|---|---|---|
| 1 | **Menú QR del comensal** (grilla, buscador, selector de producto) | Tarjeta/presentación/opción/adición pasa a «Agotado» y se deshabilita; vuelve a habilitarse sola | Línea afectada resaltada «Agotado» + opción de quitarla; resto intacto | «Confirmar pedido» bloqueado mientras haya líneas afectadas | Sí, discreto |
| 2 ★ | **Pasos de pago del QR** (`method`, `cash`, `transfer`, `review`) | — (no hay catálogo) | Línea afectada marcada **en el resumen del pedido** (spec 092); alerta visible | «Confirmar pedido» bloqueado; botón **«Volver al carrito»**; **no** cambia de paso solo | Sí |
| 3 | **Terminal — mesa** (borrador `draftLines`) | Tarjetas/presentaciones/opciones en vivo | Línea afectada derivada (`cartView`); botón de quitar | «Crear pedido» deshabilitado | Sí (cabecera) |
| 4 | **Terminal — para llevar** | ídem 3 | ídem 3 | ídem 3 | Sí |
| 5 | **Terminal — domicilio** | ídem 3 | ídem 3 | ídem 3 (además de los datos de entrega) | Sí |
| 6 | **Página de orden manual** (`manual-order-page`) | ídem 3 (misma store) | ídem 3 | ídem 3 | Sí |
| 7 | **Drawer «agregar a orden existente»** (`pos-catalog-drawer`) | Tarjetas y presentaciones en vivo | No hay borrador: agrega directo | Un intento sobre algo agotado recibe el 409 unificado y se actualiza | Sí |
| 8 | **Carta del menú** (Cajero/Admin, `products-page`) | Se actualizan interruptor y etiqueta de la **fila visible** solo por cambios **manuales** (`sold_out`); refresca solo esa fila (`GET /products/{id}`) | — | — | Sí |

## «Línea afectada» (Terminal y QR)

Derivada, nunca guardada ([data-model.md](../data-model.md)). Para cada línea resuelve **por id contra
el menú vivo** (no contra la copia que guarda `DraftLine`):

1. producto agotado → muestra «Agotado» y el nombre del producto;
2. presentación elegida agotada → «Agotado: <producto> · <presentación>»;
3. opción/sabor/salsa elegida agotada → «Agotado: <opción>»;
4. adición agotada → «Agotado: <adición>»;
5. línea marcada por un 409 `motivo = cantidad` → «No alcanza para esa cantidad».

Otras líneas del mismo producto con otra presentación/opción disponible **no** se marcan (FR-017).
La marca se retira sola cuando el elemento vuelve (FR-016). Quitar la línea solo lo hace la persona
(FR-018).

## Pasos de pago del QR — detalle (FR-019)

- Se conserva todo lo ya llenado (`CheckoutProgressStore` no se toca).
- Quitada la línea y bajado el total: aviso «El total cambió a $X»; método y comprobante se
  conservan.
- Pago **mixto**: solo si `cash_amount >= nuevoTotal` se pide corregir el efectivo (regla de la
  spec 130, que invalida el comprobante).
- No se valida automáticamente el monto del comprobante contra el nuevo total (Edge Case): el cajero
  lo compara al revisar el pago, como hoy.

## Indicador «Sin actualización en vivo» (FR-025)

- Componente `LiveStatusIndicatorComponent`: texto fijo, `role="status"`, `aria-live="polite"`,
  discreto (no modal, no banner bloqueante, no desplaza el contenido).
- Aparece cuando `RealtimeService.status ≠ 'open'` lleva **5 s continuos**; un corte menor no
  parpadea (US5.6).
- Desaparece al reconciliarse con éxito (FR-026).
- No bloquea ni deshabilita nada: se puede seguir armando y enviando (FR-029).

## Eventos del navegador que disparan reconciliación

| Disparador | Condición |
|---|---|
| `RealtimeService` `reconnected` | siempre |
| `RealtimeService` `resync` | siempre |
| `availability.changed` con `refresh: true` | siempre |
| `document.visibilitychange → visible` | pestaña oculta > 10 s **o** `status ≠ 'open'` |
| 409 por agotado | tras parchar con los `agotados[]` |

## Accesibilidad y texto

- Alertas con `role="alert"` (el 409) y `role="status"` (el aviso de total / indicador).
- Texto de la alerta: exactamente el formato de FR-024; las demás cadenas en español de Colombia.
- «Agotado» no depende solo del color (etiqueta de texto + `aria-disabled`).
