# Contrato — Presentación de fechas en el frontend (FR-008, FR-009)

**Regla**: todo instante que `pos-heladeria` muestra o del que deriva un día/hora pasa por **un único módulo** que usa
la zona del tenant. Nadie llama directamente a `toLocale*String`, `getHours()`/`getDay()`/…, `DatePipe` ni
`formatDate` con una zona IANA. **Sin dependencias nuevas** (`Intl` basta; Principio IX).

## 1. API compartida

### `src/app/shared/date-format.util.ts` (existe; se amplía)

```ts
/** Única zona de respaldo del frontend (hoy repetida en 4 archivos). */
export const FALLBACK_TIMEZONE = 'America/Bogota';

/** `YYYY-MM-DD` de «hoy» en la zona dada. Existe, sin cambio. */
export function businessToday(timezone: string): string;

export interface ZonedParts {
  year: number; month: number; day: number;          // calendario de la zona
  hour: number; minute: number; second: number;      // 0–23
  weekday: number;                                   // 0 = lunes … 6 = domingo (igual que el backend)
  ymd: string;                                       // 'YYYY-MM-DD'
  hhmm: string;                                      // 'HH:mm'
}
/** Componentes de pared de un instante en la zona dada; `null` si el valor no es una fecha válida. */
export function zonedParts(instant: Date | string | number, timezone: string): ZonedParts | null;

/** `Intl.DateTimeFormat(locale, { ...options, timeZone })`. Único punto con `toLocale*` en el código de la app. */
export function formatInZone(
  instant: Date | string | number, timezone: string,
  options: Intl.DateTimeFormatOptions, locale = 'es-CO',
): string;
```

### `TenantInfoService` (existe; se amplía)

```ts
readonly timezone = computed(() => this.info()?.timezone ?? FALLBACK_TIMEZONE);
```

### `TenantDatePipe` (existe; se amplía)

```ts
transform(value, format = 'medium', timezone?: string): string | null
//  timezone explícita > tenantInfo.timezone() > FALLBACK_TIMEZONE
```

`ianaOffset` se conserva dentro del pipe (corrige la limitación conocida de `formatDate` con nombres IANA).
`DEFAULT_TIMEZONE` privado **desaparece** de `tenant-date.pipe.ts`, `reports.service.ts`, `promotions-page.component.ts`
y `promotion.service.ts`; todos importan `FALLBACK_TIMEZONE`.

### `src/app/shared/tenant-timezones.ts` (nuevo)

`TENANT_TIMEZONE_OPTIONS: { value: string; label: string }[]` con las siete zonas de
[data-model.md §3](../data-model.md); el formulario de alta construye el `<select>` a partir de ella.

## 2. Sitios a corregir (inventario cerrado)

| # | Archivo (`pos-heladeria/src/app/…`) | Hoy (zona del navegador) | Después |
|---|---|---|---|
| 1 | `modules/tables/services/receipt.util.ts` `formatDateTime` (+ 4 llamadores de `buildReceiptHtml`: `pos-terminal.store.ts` ×2, `sales-page`, `tenant-info.component` ticket de prueba) | `getDate()/getHours()…` | `zonedParts(iso, opts.timezone)`; `ReceiptOptions.timezone` |
| 2 | `modules/tables/components/pos-terminal-header.component.ts` (reloj, fecha, turno) | `toLocaleTimeString`, `getHours()` | `formatInZone` + `zonedParts(…).hour` con la zona del tenant |
| 3 | `modules/tables/services/pos-terminal.store.ts:921` `createdAtLabel` | `toLocaleTimeString('es-CO')` | `formatInZone` |
| 4 | `modules/dashboard/components/shift-sales-report-card.component.ts:144` | `toLocaleString('es-CO')` | `formatInZone` |
| 5 | `modules/dashboard/pages/admin-dashboard.component.ts` (saludo `:338`, ejes `:538-543`) | `getHours()`, `toLocale*` | `zonedParts` / `formatInZone` (hora, `Sem d/m`, día) |
| 6 | `modules/dashboard/layout/header.component.ts:86` | `\| date: 'short'` | `\| tenantDate: 'short'` |
| 7 | `modules/dashboard/layout/tenant-header.component.ts:173` | `\| date: 'short'` | `\| tenantDate: 'short'` |
| 8 | `modules/plan/pages/plan-summary-page.component.ts:55` | `\| date: 'mediumDate'` | `\| tenantDate: 'mediumDate'` |
| 9 | `modules/super-admin/pages/tenants-page.component.ts:112` | `\| date: 'mediumDate'` | `\| tenantDate: 'mediumDate' : t.timezone` |
| 10 | `modules/users/components/pending-invitations-list.component.ts:43` | `\| date: 'dd/MM/yyyy HH:mm'` | `\| tenantDate: 'dd/MM/yyyy HH:mm'` |
| 11 | `modules/tables/pages/public-menu.component.ts:1616` + `tables/services/diner.service.ts` | `toLocaleTimeString([])` | `formatInZone(…, business.timezone)`; `ResolvedBusiness.timezone` |
| 12 | `modules/inventory/pages/inventory-page.component.ts:654` | `toISOString().slice(0,10)` (día UTC) | `businessToday(tenantInfo.timezone())` |
| 13 | `modules/reports/services/reports.service.ts:22,63` | `DEFAULT_TIMEZONE`; `new Date().toLocaleDateString('en-CA')` | `FALLBACK_TIMEZONE`; `businessToday(timezone())` |
| 14 | `modules/promotions/pages/promotions-page.component.ts:46,1670` | `DEFAULT_TIMEZONE`; `getPromoDisplay(p, now)` | `FALLBACK_TIMEZONE`; pasa la zona |
| 15 | `modules/promotions/services/promotion.service.ts:40` | `DEFAULT_TIMEZONE` | `FALLBACK_TIMEZONE` |
| 16 | `modules/promotions/services/promotion-pricing.util.ts` `isPromoActiveNow` / `getPromoDisplay` | `getDay()`, `toTimeString()`, `new Date(promo.starts_at)` | `zonedParts(now, tz)`; `starts_at` comparado como hora de pared |
| 17 | `shared/pipes/tenant-date.pipe.ts` | `DEFAULT_TIMEZONE` privado | 3.er parámetro + `FALLBACK_TIMEZONE` |
| 18 | `core/tenant/tenant-info.service.ts` | — | `timezone` computado |
| 19 | `shared/date-format.util.ts` | — | `FALLBACK_TIMEZONE`, `zonedParts`, `formatInZone` |
| 20 | `modules/super-admin/components/tenant-form.component.ts` + `interfaces/tenant.interface.ts` | — | `<select>` de zona obligatorio, sin valor inicial; `timezone` en el payload |
| 21 | `shared/tenant-timezones.ts` | — | nuevo |

**Revisados y sin cambio** (aritmética de calendario sobre una fecha ya local, o instantes puros):
`reports.service.ts::getDateRange` y `fmt`, `reports-page.component.ts::bucketLabel` (`getDay` sobre una fecha ya local),
`order-date-filter.component.ts`, `orders-page.component.ts`,
`cash-session.store.ts` (`Date.now()`, `tenantDate`), `admin-dashboard.component.ts::loadTrend`,
`promotions-page.component.ts::fmtDate` (mediodía local fijo), `checkout-progress.store.ts` (`saved_at` ISO),
`jwt.util.ts`, `app-update.service.ts`, `forgot-password.component.ts`, `auth-shell.component.ts` (año del pie).

## 3. Regla del turno (Mañana / Tarde / Noche)

Se conserva el criterio actual — `hora < 12` Mañana, `< 19` Tarde, resto Noche — pero la **hora es la del tenant**
(`zonedParts(now, timezone).hour`), no la del navegador. Igual el saludo del Dashboard (`< 12`, `< 19`).

## 4. Vigencia visual de promociones (`isPromoActiveNow`)

Firma nueva: `isPromoActiveNow(promo, now: Date, timezone: string)`. Con `p = zonedParts(now, timezone)`:

- estado `active`; **inicio**: `p.ymd + 'T' + hh:mm:ss` (hora de pared del tenant) `<` `promo.starts_at.slice(0,19)` ⇒ no vigente;
- **fin**: `p.ymd > promo.ends_at.slice(0,10)` ⇒ no vigente;
- **día de la semana**: `p.weekday`; **ventana horaria**: `p.hhmm` contra `start_time`/`end_time`.

`starts_at`/`ends_at` **no** se pasan por `new Date()` (son hora de pared, FR-002).

## 5. Prueba de guarda (contraparte de `test_instantes_forma_unica.py`)

`src/app/shared/date-usage.guard.spec.ts` lee las fuentes `.ts` (no `.spec.ts`) de `src/app` con `node:fs`
(**comprobado**: el constructor de pruebas de Angular 21 lo permite) y falla ante:

Las reglas son **expresiones regulares exactas**, no subcadenas: `DatePipe` casaría con `TenantDatePipe` (importado en ~10
archivos) y `formatDate(` con los métodos propios `store.formatDate(` que sí usan el tenant.

- `DatePipe` / `formatDate` de Angular: solo como **importación**, `import\s*\{[^}]*\b(DatePipe|formatDate)\b[^}]*\}\s*from\s*'@angular/common'`.
- Pipe `date` en plantillas: `\|\s*date\s*[:}\s]`.
- Componentes de fecha del navegador: `\.(getHours|getMinutes|getSeconds|getDay|getDate|getMonth|getFullYear|toTimeString|toDateString)\(`.
- `toLocale*` de fechas: `\.toLocale(Date|Time)String\(`; y `\.toLocaleString\(` solo si sus opciones traen
  `hour|minute|day|month|year|weekday` (el de **números**, que formatea dinero, está permitido).
- Día UTC: `toISOString\(\)\.(slice|substring|split)`.
- `Intl\.DateTimeFormat`: permitido solo en `date-format.util.ts` y `tenant-date.pipe.ts`.

Las excepciones se declaran **por archivo y por texto literal de la línea permitida**, cada una comentada con su razón (el
propio `date-format.util.ts`, `tenant-date.pipe.ts` que envuelve `formatDate`, y los sitios de aritmética de calendario de la
sección 2 «sin cambio»). Una excepción **no** exime a todo el archivo: un `getHours()` nuevo en `admin-dashboard.component.ts`
debe seguir fallando aunque `loadTrend` esté exceptuado.

## 6. Pruebas con la zona del sistema forzada

`TZ=Asia/Tokyo npx ng test --watch=false` y `TZ=UTC npx ng test --watch=false` (el `TZ` llega a vitest; comprobado el
2026-10-25: las 154 pruebas de los 9 specs de fechas pasan en Bogotá, Tokio y UTC **hoy**, lo que confirma que no
detectan nada hasta que se agreguen los casos con zonas de tenant distintas).
