# Quickstart: validar la carga agregada (bootstrap) del panel de staff

**Spec**: [spec.md](spec.md) | **Contrato**: [contracts/bootstrap-endpoint.md](contracts/bootstrap-endpoint.md)

Guía para comprobar, de punta a punta, que la funcionalidad cumple los criterios de aceptación del
spec. No repite código de implementación — solo comandos y resultados esperados.

## Prerrequisitos

- Backend: `cd ../pos-backend && uvicorn app.main:app --reload`.
- Frontend: `cd ../pos-heladeria && ng serve`.
- Un usuario de prueba staff/administrador de un tenant con datos reales de negocio, plan y al
  menos una notificación reciente (p. ej. un pedido nuevo desde el menú QR).
- El usuario Super Admin ya sembrado (`_seed_shared_data`, sin tenant ni plan asociados).
- Herramientas de red del navegador (pestaña "Network" de DevTools) para contar peticiones HTTP.

## 1. Un solo request para staff/administrador de un tenant (US1, SC-001)

1. Abrir la pestaña "Network" del navegador, filtrar por `Fetch/XHR`, limpiarla.
2. Iniciar sesión como staff/administrador del tenant de prueba.
3. **Esperado**: aparece exactamente una petición `GET /api/v1/bootstrap` (en vez de las 3+
   peticiones separadas `GET /tenant`, `GET /plan`, `GET /notifications` que se veían antes del
   cambio) — más la petición independiente `POST /realtime/ticket` (sin cambios, FR-004).
4. **Esperado**: el panel se pinta igual de completo que antes — nombre del negocio en el header,
   datos del plan donde correspondan, contador y lista del centro de notificaciones con el mismo
   contenido reciente.
5. Confirmar en la respuesta de `GET /api/v1/bootstrap` que los 3 bloques (`tenant`, `plan`,
   `notifications`) tienen contenido, con la misma forma documentada en
   `contracts/bootstrap-endpoint.md` § Caso 1.

## 2. Refrescos puntuales siguen usando las rutas individuales (US1, SC-004)

1. Con el panel ya cargado del paso anterior, abrir "Ajustes" y editar un dato de negocio (p. ej.
   el nombre o el mensaje del recibo) y guardar.
2. **Esperado**: en la pestaña de red aparece `PATCH /tenant` seguido de `GET /tenant` (o el flujo
   de refresco que ya exista) — **no** una nueva llamada a `GET /bootstrap`.
3. Repetir un cambio equivalente que dispare un refresco de plan o de notificaciones (si aplica un
   flujo manual, o verificar en el código que `tenantInfo.load()`/`planSummaryService.load()`
   siguen siendo los métodos invocados ahí) y confirmar lo mismo: solo la ruta individual
   correspondiente, nunca `/bootstrap`.

## 3. Super Admin carga sin error (US2, SC-003)

1. Cerrar sesión e iniciar sesión como Super Admin.
2. **Esperado**: el panel termina de cargar sin pantalla en blanco ni bloqueo — los bloques de
   negocio/plan quedan vacíos (sin mostrar nombre de negocio ni datos de plan), pero el resto del
   shell (header, sidebar, navegación de super-admin) funciona con normalidad.
3. En la pestaña de red, confirmar que `GET /api/v1/bootstrap` respondió `200` (no `404`) con el
   body documentado en `contracts/bootstrap-endpoint.md` § Caso 2
   (`{ "tenant": null, "plan": null, "notifications": null }`).

Automatizado (backend):

```bash
cd ../pos-backend
python -m unittest app.characterization_tests.test_bootstrap -v
```

Debe incluir al menos un caso que llama al bootstrap autenticado como Super Admin y verifica
`200` + los 3 bloques en `null`.

## 4. Continuidad ante fallo total o parcial (US3, SC-002)

**Fallo total** (simulado, p. ej. con DevTools → Network → bloquear la URL
`**/api/v1/bootstrap` o cortando la red momentáneamente antes del login):

1. Iniciar sesión con el `/bootstrap` bloqueado/caído.
2. **Esperado**: el panel sigue siendo usable, mostrando los mismos valores por defecto actuales
   (esquema vacío) que ya mostraba antes de esta funcionalidad cuando una fuente individual
   fallaba — sin pantalla en blanco.
3. **Esperado**: en la pestaña de red, dentro de esa misma carga de página, **no** aparecen
   reintentos automáticos de `GET /tenant`, `GET /plan` ni `GET /notifications` disparados por el
   fallo del bootstrap (FR-005) — sí puede aparecer `POST /realtime/ticket` normalmente, porque es
   independiente (FR-004).

**Fallo parcial de una sola fuente interna** (más fácil de forzar desde el backend, p. ej. un
`raise` temporal dentro de la construcción del bloque `notifications`, o un dato que haga fallar
esa consulta puntual):

1. Con solo la fuente de notificaciones fallando, iniciar sesión como staff/administrador del
   tenant de prueba.
2. **Esperado**: `GET /api/v1/bootstrap` responde `200` con `tenant`/`plan` completos y
   `notifications: null` — el panel muestra negocio y plan con normalidad, y el centro de
   notificaciones queda en su estado vacío por defecto (sin bloquear el resto del panel).

Automatizado (backend):

```bash
cd ../pos-backend
python -m unittest app.characterization_tests.test_bootstrap -v
```

Debe incluir casos que fuerzan el fallo de exactamente una fuente (tenant, plan, o notifications
por separado) y verifican que las otras dos siguen completas en la misma respuesta `200`.

## 5. El ticket de tiempo real sigue funcionando igual (US1 Acceptance Scenario 3, FR-004/FR-009)

1. Con el panel ya cargado (vía bootstrap exitoso, parcial o tras un fallo total), confirmar en la
   pestaña de red que `POST /realtime/ticket` se sigue pidiendo como petición individual, y que
   `GET /realtime/stream` se abre con normalidad después.
2. Disparar un evento en tiempo real (p. ej. un pedido nuevo desde el menú QR de una mesa del
   mismo tenant) y confirmar que el aviso llega al panel con normalidad, sin importar si el
   bootstrap de esa carga fue exitoso, parcial o fallido.

## 6. Verificación de la guarda de una sola ejecución en notificaciones (research.md Decisión 8)

Frontend:

```bash
cd ../pos-heladeria
ng test --include='**/notification-center.service.spec.ts'
ng test --include='**/bootstrap.service.spec.ts'
```

Debe incluir un caso que fuerza el orden "el bootstrap llega primero" y otro "el auto-arranque por
DI corre primero" (simulando ambos órdenes posibles en el test, ya que Angular no lo garantiza en
producción) y verifica en ambos que `GET /notifications` se dispara **como máximo una vez** por
carga de página.

## Resumen de comandos de verificación

```bash
# Backend
cd ../pos-backend
python -m unittest app.characterization_tests.test_bootstrap -v
python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v   # suite completa, sin regresiones

# Frontend
cd ../pos-heladeria
ng test --include='**/bootstrap.service.spec.ts'
ng test --include='**/notification-center.service.spec.ts'
ng test --include='**/tenant-info.service.spec.ts'
ng test --include='**/plan-summary.service.spec.ts'
ng test   # suite completa, sin regresiones (ver reference_pos_suite_frontend_fallos_preexistentes para la línea base de fallos ajenos conocidos)
```
