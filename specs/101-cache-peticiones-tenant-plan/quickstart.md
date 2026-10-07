# Quickstart: validar la caché y deduplicación de `load()` en TenantInfoService / PlanSummaryService

**Spec**: [spec.md](spec.md) | **Contrato**: [contracts/load-contract.md](contracts/load-contract.md)

Guía para comprobar, de punta a punta, que la funcionalidad cumple los criterios de aceptación del
spec. No repite código de implementación — solo comandos y resultados esperados. Como el alcance
excluye deliberadamente cualquier cambio visible en componentes (FR-008, Clarification 1), la
verificación principal es automatizada (tests unitarios directos sobre los servicios); el recorrido
manual en navegador solo confirma que el comportamiento ya cubierto por tests también se observa en
la aplicación real, para la Historia 1 (la única con llamadores reales hoy).

## Prerrequisitos

- Frontend: `cd ../pos-heladeria && ng serve`.
- Un usuario de prueba staff/administrador de un tenant con datos de negocio y plan ya cargados.
- Herramientas de red del navegador (pestaña "Network" de DevTools) para contar peticiones HTTP.

## 1. Automatizado — Historia 1: cache-hit y deduplicación (US1, SC-001, SC-002)

```bash
cd ../pos-heladeria
ng test --include='**/cached-loader.util.spec.ts'
ng test --include='**/tenant-info.service.spec.ts'
ng test --include='**/plan-summary.service.spec.ts'
```

**Esperado**: los nuevos casos cubren, para ambos servicios y para el helper en sí:

- `load()` con datos ya en memoria (o ya hidratados vía `hydrate()`) no dispara ninguna petición
  HTTP (`HttpTestingController.expectNone` o equivalente) — Acceptance Scenario 1 de Historia 1.
- Dos llamadas a `load()` casi simultáneas, antes de que la primera responda, resultan en
  exactamente una petición HTTP (`http.expectOne`, sin una segunda pendiente) y ambas `Promise`
  devueltas resuelven con el mismo signal final — Acceptance Scenario 2.
- Tras un `load()` que termina en error, una llamada posterior sin forzar sí dispara una nueva
  petición HTTP (no queda bloqueada por el intento fallido) — Acceptance Scenario 3.
- Ningún caso de cache-hit o deduplicación modifica `loading()` ni `error()` en ningún instante
  intermedio (FR-011) — se verifica leyendo esos signals antes/durante/después de la llamada
  cacheada o unida, no solo su valor final.

## 2. Automatizado — Historia 2: forzado (US2, SC-003, SC-004)

Mismos comandos que el paso 1 (están en los mismos archivos de spec). **Esperado**: los casos
nuevos cubren:

- Con datos ya cacheados, `load({ force: true })` dispara una petición HTTP real igual (`http.
  expectOne`) — Acceptance Scenario 1 de Historia 2.
- Tras una recarga forzada exitosa, el signal de datos y el caché quedan con la respuesta nueva —
  Acceptance Scenario 2.
- Después de esa recarga forzada, una llamada a `load()` sin forzar no dispara una petición
  adicional (vuelve a resolver por caché, con el valor nuevo) — Acceptance Scenario 3.
- Un `force` que llega mientras ya hay una petición normal en curso dispara una segunda petición
  HTTP real distinta de la primera (dos `http.expectOne` independientes, no una sola reutilizada) —
  cubre el Edge Case de peticiones solapadas de spec.md y el Caso 4 de
  `contracts/load-contract.md`.

## 3. Manual en navegador — Historia 1 observable con los llamadores reales hoy

Como no existe hoy ningún llamador real de `force` (Clarification 1), este recorrido manual solo
cubre la Historia 1 (cache-hit/deduplicación), que sí es observable con la navegación normal del
panel.

1. Iniciar sesión como staff/administrador del tenant de prueba; esperar a que el panel cargue por
   completo (dispara el bootstrap agregado de la spec 100, que ya hidrata `info`/`summary` sin HTTP
   propio).
2. Abrir la pestaña "Network" del navegador, filtrar por `Fetch/XHR`, limpiarla.
3. Navegar a una pantalla que llama a `tenantInfo.load()` o `planSummaryService.load()` sin
   forzado hoy (p. ej. "Ventas", "Inventario", o "Mi plan").
4. **Esperado**: no aparece ninguna petición nueva `GET /tenant` ni `GET /plan` en esa navegación —
   ambos servicios ya tenían datos en memoria desde el bootstrap inicial (Caso 1 del contrato).
5. Navegar entre dos o más de esas pantallas varias veces seguidas.
6. **Esperado**: sigue sin aparecer ninguna petición nueva a `GET /tenant` ni `GET /plan` en ningún
   momento de esa navegación — antes de este cambio, cada una de esas pantallas disparaba su propio
   `load()` sin comprobar caché a nivel de servicio (las comprobaciones que SÍ hacían esos
   componentes antes de llamar a `load()` seguían disparando la petición en algunos casos; ahora el
   propio servicio la evita siempre).

No hay un paso manual equivalente para `force`, ya que su único punto de verificación son los tests
directos del paso 2 (Clarification 1 de spec.md).

## Resumen de comandos de verificación

```bash
cd ../pos-heladeria
ng test --include='**/cached-loader.util.spec.ts'
ng test --include='**/tenant-info.service.spec.ts'
ng test --include='**/plan-summary.service.spec.ts'
ng test   # suite completa, sin regresiones (ver reference_pos_suite_frontend_fallos_preexistentes para la línea base de fallos ajenos conocidos)
```
