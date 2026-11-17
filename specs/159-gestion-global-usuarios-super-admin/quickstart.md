# Quickstart: Gestión global de usuarios en el panel Super Admin

Guía de validación end-to-end por User Story. Asume `pos-backend` corriendo localmente con
Postgres real (ver memoria del proyecto: Postgres local disponible, venv de `pos-backend`
para tests) y `pos-heladeria` servido con `ng serve`, autenticado como un usuario con
`tenant_id IS NULL` (Super Admin).

## Prerrequisitos

```bash
# pos-backend
cd ../pos-backend
alembic upgrade head          # aplica las migraciones de data-model.md
python app/scripts/seed_super_admin.py   # si aún no hay un Super Admin local
uvicorn app.main:app --reload --port 8000

# pos-heladeria
cd ../pos-heladeria
npm start
```

Datos de prueba sugeridos (vía script/seed o creados a mano en el panel):
- Al menos 2 negocios (tenants) con planes distintos.
- Un usuario con membresías en 2 negocios con roles distintos (valida Decisión 1/FR-014).
- Un usuario sin ningún negocio asociado (valida FR-015).
- Un usuario `pending_activation`, uno con una `UserInvitation` pendiente, uno `suspended`,
  uno con varias sesiones activas.
- Más de 2 Super Admin activos en el ambiente de prueba (para poder validar el bloqueo del
  "último Super Admin" sin dejar el ambiente sin acceso — Decisión 8).

## User Story 1+2 — Listado centralizado e indicadores (P1)

1. Abrir el módulo de Usuarios del panel Super Admin.
2. Verificar que los 4 indicadores (`GET /super-admin/users/stats`) coinciden con un conteo
   manual de los datos sembrados.
3. Buscar por nombre/correo/negocio parcial y confirmar que la tabla se filtra en vivo
   (`GET /super-admin/users?search=...`).
4. Combinar `status`+`role_id`+rango de fechas y confirmar que la URL/query refleja todos los
   filtros a la vez, y que "Limpiar filtros" los remueve en una sola acción.
5. Ordenar por "Último acceso" y por "Fecha de registro"; confirmar que el header refleja
   asc/desc y que filtros+búsqueda se mantienen tras reordenar.
6. Verificar que el usuario con 2 negocios muestra el indicador "+N" y que el usuario sin
   negocio muestra un estado explícito, no una celda vacía.
7. Suspender un usuario desde el listado y confirmar que los indicadores
   activos/suspendidos cambian sin recargar manualmente (SC vinculado a FR-009).

## User Story 3+6 — Ficha individual y seguridad (P1/P2)

1. Abrir la ficha de un usuario con 2 membresías: confirmar que la pestaña "Negocios
   asociados" lista ambos negocios con su plan y el rol específico en cada uno.
2. Abrir la ficha de un usuario con sesiones activas simuladas (login desde 2
   clientes/navegadores distintos): confirmar que "Seguridad" lista cada sesión con
   dispositivo/navegador/IP (`GET /super-admin/users/{id}/security`).
3. Provocar varios logins fallidos consecutivos contra un usuario de prueba hasta cruzar el
   umbral configurado; confirmar que su `status` pasa a "Bloqueado por seguridad" (visible en
   listado y ficha) y que el Super Admin puede desbloquearlo manualmente
   (`POST /super-admin/users/{id}/activate`).
4. Revocar todas las sesiones de un usuario desde su ficha; confirmar que la lista de
   sesiones queda vacía de inmediato y que aparece en su pestaña de Actividad y en
   `GET /super-admin/audit-logs`.
5. Abrir la ficha de un usuario sin sesiones activas: confirmar el estado vacío y que el
   control de revocar está deshabilitado.

## User Story 4 — Administración (P2)

1. Cambiar el rol de un usuario y confirmar que el cambio se refleja de inmediato en listado
   y ficha, y queda en su historial de actividad.
2. Suspender un usuario activo sin indicar motivo: confirmar que el sistema bloquea la
   confirmación hasta escribir/seleccionar un motivo (FR-019).
3. Reactivar ese mismo usuario y confirmar que recupera `status=active` y puede volver a
   iniciar sesión.
4. Enviar una recuperación de contraseña y confirmar el correo saliente (o el job en Celery)
   y la constancia en el historial.
5. Intentar suspender/anonimizar/eliminar al único Super Admin activo del ambiente de prueba
   (reducir temporalmente a 1 si es necesario) y confirmar el bloqueo con advertencia
   (Decisión 8, FR-026) — luego restaurar el segundo Super Admin.

## User Story 5 — Anonimizar / eliminar (P3)

1. Anonimizar un usuario de prueba escribiendo su correo como confirmación; verificar que
   nombre/correo quedan anonimizados, que ya no puede iniciar sesión, y que cualquier venta
   histórica ligada a él sigue existiendo sin datos personales visibles.
2. Confirmar que las acciones que ya no aplican (editar datos personales, recuperar
   contraseña) están deshabilitadas/ocultas en su ficha (FR-027).
3. Intentar eliminar permanentemente a un usuario con registros transaccionales en algún
   tenant; confirmar el bloqueo con motivo y la alternativa de anonimizar ofrecida
   (FR-024/Edge case).
4. Eliminar permanentemente a un usuario de prueba sin registros transaccionales; confirmar
   que desaparece del listado y que su eliminación sigue siendo consultable en
   `GET /super-admin/audit-logs` (FR-038).

## User Story 7 — Auditoría (P2)

1. Repetir 3-4 acciones administrativas de las secciones anteriores y confirmar que cada una
   aparece en `GET /super-admin/audit-logs` con administrador, usuario afectado, negocio,
   tipo, fecha/hora e IP.
2. Confirmar que el bloqueo automático por intentos fallidos (User Story 6, paso 3) aparece
   etiquetado como "Sistema", visualmente distinto de las acciones de administrador.
3. Filtrar por usuario, administrador, negocio, tipo de acción y rango de fechas, combinados;
   confirmar que los resultados son la intersección de todos los filtros.
4. Hacer clic en el usuario afectado de un registro y confirmar que abre su ficha sin perder
   el contexto de los filtros de auditoría al volver.
5. Filtrar con una combinación sin coincidencias y confirmar el estado vacío específico
   (FR-041).

## User Story 8 — Navegación e integración (P1)

1. Navegar entre Tenants, Usuarios, Métodos de pago, Planes y la nueva sección de Auditoría
   desde el sidebar del panel Super Admin; confirmar que ningún módulo existente cambió de
   comportamiento.
2. Confirmar visualmente que Usuarios y Auditoría comparten tipografía, colores y estructura
   de sidebar/navbar con el resto del panel.

## Verificación automatizada

- `pos-backend`: correr characterization tests de auth (`test_auth_session_revocation.py`,
  `test_auth_session_name_claim.py`) sin modificarlos y en verde, más los tests nuevos de
  este módulo (lockout, sesiones, membresías, anonimización/eliminación, bitácora).
- `pos-heladeria`: suite del módulo `super-admin` (listado paginado, ficha, formularios y
  modales de confirmación) — ver nota operativa sobre asentamiento de componentes con
  queries paginadas (varias rondas de `tick`/`detectChanges`).
