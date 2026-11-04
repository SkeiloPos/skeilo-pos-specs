# Línea base de las suites (T004)

**Fecha**: 2026-11-02, antes de tocar código (rama `feat/148-product-availability-realtime`
recién creada en ambos repos, desde `develop`).

## Backend (`pos-backend`)

```
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

**Resultado**: `Ran 2092 tests in 140.013s` → **OK** (0 fallos).

## Frontend (`pos-heladeria`)

```
ng test --watch=false
```

**Resultado**: `Test Files 10 failed | 163 passed (173)` · `Tests 79 failed | 2495 passed | 1 skipped (2575)`.

Comparación por **nombre de archivo**, no por conteo total (la suite es conocida por tener fallos
preexistentes no relacionados con esta spec — ver memoria del proyecto).

### Archivos con al menos un fallo preexistente

- `src/app/app.spec.ts`
- `src/app/core/services/auth.service.spec.ts`
- `src/app/core/services/menu.service.spec.ts`
- `src/app/modules/promotions/pages/promotions-page.component.spec.ts`
- `src/app/modules/super-admin/services/tenant.service.spec.ts`
- `src/app/modules/tables/components/pos-checkout-panel.component.spec.ts`
- `src/app/modules/tables/components/pos-order-panel.component.spec.ts`
- `src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- `src/app/modules/tables/services/pos-terminal.store.spec.ts`
- `src/app/shared/date-usage.guard.spec.ts`

### Nombres de prueba fallidos capturados (no exhaustivo, el resto queda en el log)

- `date-usage.guard.spec.ts > guarda de uso de fechas (spec 138) > ningún fuente usa la fecha/hora del navegador fuera del módulo único y de las excepciones documentadas`
- `auth.service.spec.ts > AuthService.login > clears mustChangePassword after a successful password change`
- `menu.service.spec.ts > MenuService — la terminal gana la condición, ningún importe (spec 066) > NO mapea discounted_price ni discount_kind: el modal sigue mostrando $8.000 (FR-017)`
- `promotions-page.component.spec.ts > switch "Visible en QR" en el listado > el control permanece visible y habilitado para status=paused (FR-010, no solo para Activa)`
- `promotions-page.component.spec.ts > switch "Visible en QR" en el listado > el control permanece visible y habilitado para status=finished (FR-010, no solo para Activa)`
- `tenant.service.spec.ts > TenantService > creates a tenant with the user payload via POST /super-admin/tenants`
- `tenant.service.spec.ts > TenantService > maps a FastAPI 422 (detail as array) to a readable message`
- `tenant.service.spec.ts > TenantService > maps a string detail error`
- `pos-checkout-panel.component.spec.ts > T032: ofrece "Imprimir Pre-cuenta" cuando hay cuenta de sesión`
- `pos-order-panel.component.spec.ts > conserva "Marcar pedido listo" fuera del contenedor de totales retirado`
- `pos-order-panel.component.spec.ts > "Marcar pedido listo" (en la cabecera, a pedido del usuario) queda shrink-0, fuera de la lista scrolleable (FR-023)`
- `manual-order-page.component.spec.ts > bugfix: reabrir el modal para el mismo producto arranca sin las adiciones de la línea anterior`
- `manual-order-page.component.spec.ts > T038: agregar desde la categoría original (no "Promociones") deja la línea en cantidad 1`
- `manual-order-page.component.spec.ts > T039: encontrar el producto con el buscador (sin pasar por "Promociones") deja la línea en cantidad 1`
- `pos-terminal.store.spec.ts > saveOrder() con dos líneas hermanas hace dos llamadas a addOrderItems, una por línea`

**Referencia para T107/T108**: tras implementar, ningún archivo nuevo debe aparecer en esta lista
y ningún fallo nuevo (por nombre) debe aparecer en los archivos ya listados. Se permite que
`menu.service.spec.ts` gane pruebas nuevas en verde (T026/T027 de esta spec la amplían).

## Resultado final (T107/T108, tras implementar las 6 historias + Polish)

**Backend**: `Ran 2163 tests in 145.517s` → **OK** (0 fallos). Sube de 2092 a 2163 (+71 tests
nuevos: motor de disponibilidad, eventos, snapshot, gancho de inventario, 409 unificado,
aislamiento). 0 regresiones.

**Frontend**: `Test Files 9 failed | 172 passed (181)` · `Tests 15 failed | 2702 passed | 1 skipped
(2718)`. Sube de 2495 a 2702 pruebas en verde (+207). Los 9 archivos con fallo son el mismo
conjunto preexistente de la línea base (`app.spec.ts`, `auth.service.spec.ts`,
`menu.service.spec.ts`, `tenant.service.spec.ts`, `pos-checkout-panel`, `pos-order-panel`,
`manual-order-page`, `pos-terminal.store.spec.ts`, `date-usage.guard.spec.ts`), con los mismos
nombres de prueba fallando — **0 regresiones nuevas**. `promotions-page.component.spec.ts` (2
fallos en la línea base) salió de la lista de fallos en esta corrida (era flaky, no algo que esta
spec haya corregido).

**Conclusión**: ninguna prueba que pasaba antes de esta spec falla después. T107/T108 PASA.
