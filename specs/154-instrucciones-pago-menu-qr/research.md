# Research: Instrucciones de Pago del Menú QR por Modalidad del Plan

**Feature**: 154-instrucciones-pago-menu-qr | **Fecha**: 2026-11-06

`spec.md` no deja ninguna pregunta de negocio abierta (la única clarificación — texto exacto
para Nequi en PAY_AFTER_RECEIVING — ya está resuelta en la sesión de Clarifications
2026-11-06). Lo que sigue es exclusivamente investigación de implementación, necesaria antes de
diseñar `data-model.md` y `contracts/`.

## 1. Dónde vive hoy el mensaje de instrucción de pago

**Decisión**: Los tres mensajes de PAY_AFTER_RECEIVING (comportamiento actual) están escritos,
como literales de plantilla, en
`pos-heladeria/src/app/modules/tables/pages/checkout/confirmation-step.component.ts`:
- Efectivo (línea 117): "Te llevaremos tu pedido a la mesa. Paga al recibirlo."
- Transferencia/Nequi (línea 126): "Muestra el comprobante de tu banco al cajero cuando
  recibas tu pedido."
- Mixto (líneas 82-83): "Al recibir tu pedido, muestra el comprobante de la transferencia al
  cajero. El efectivo lo pagas al recibirlo."

No existe ningún campo de backend que hoy transporte este texto ni la modalidad: el frontend
decide el mensaje únicamente a partir de `order.current_payment_attempt.is_cash` y de si
`cash_amount`/`transfer_amount` vienen ambos poblados (mixto).

**Razón**: Es la única pantalla que el spec señala como punto de aparición (Assumptions: "la
pantalla de confirmación del menú QR que ya existe hoy inmediatamente después de enviar la
orden"). `public-menu.component.ts` tiene copys parecidos pero en el paso de selección de
método de pago, **antes** de enviar el pedido — fuera del alcance de este spec, que no lo
menciona y que exige no mezclar esta funcionalidad con pantallas no señaladas (Principio V/VI
de la constitución).

**Alternativas consideradas**: Tocar también `public-menu.component.ts` para "ser consistentes"
— descartado: esa pantalla no muestra una instrucción de qué hacer después de pagar, muestra
el selector de método de pago antes de pagar; generalizar el cambio ahí sería una
refactorización no solicitada por el spec.

## 2. Dónde vive la modalidad: columna nueva en `Plan`, con qué forma

**Decisión**: Se agrega `Plan.modalidad_pago_qr` (`shared.plans.modalidad_pago_qr`),
`String(30)`, `NOT NULL`, `CheckConstraint("modalidad_pago_qr IN ('PAY_AFTER_RECEIVING',
'PAY_BEFORE_RECEIVING')")`, `server_default='PAY_AFTER_RECEIVING'`. Mismo estilo que
`PaymentMethodCatalog.type` (`app/models/payment_method_catalog.py`): columna `String` +
`CheckConstraint` en vez de un tipo `ENUM` de Postgres — este codebase no usa enums nativos de
Postgres para catálogos cerrados de dos-a-cinco valores, usa `String` + `CheckConstraint` +
`Literal[...]` en Pydantic.

**Razón**: FR-001/FR-002 piden "exactamente uno de dos valores... nunca ambos ni ninguno" —
igual que `PaymentMethodCatalog.type`, eso es precisamente lo que un `CheckConstraint` sobre
`String` garantiza a nivel de base de datos, sin depender de que la capa de aplicación lo
valide. El default `'PAY_AFTER_RECEIVING'` resuelve, sin backfill, el edge case "plan sin
modalidad configurada explícitamente" (spec.md Edge Cases, Assumptions) para los planes ya
existentes.

**Alternativas consideradas**:
- Columna `Boolean` (p. ej. `pago_antes_de_recibir: bool`) — descartada: aunque hoy son
  exactamente dos valores, el spec los nombra como un catálogo cerrado con nombres propios
  (PAY_AFTER_RECEIVING/PAY_BEFORE_RECEIVING), no como un interruptor; un booleano obligaría a
  traducir ese nombre en cada punto de lectura y es menos legible en los schemas/UI
  ("¿`true` es antes o después?").
- Tipo `ENUM` nativo de Postgres — descartado: ningún otro catálogo cerrado del proyecto
  (`PaymentMethodCatalog.type`, `PaymentMethod.type`) usa `ENUM` nativo; introducirlo rompería
  la consistencia sin aportar nada que el `CheckConstraint` no dé ya.
- Agregarla como un tercer booleano de módulo junto a `inventario_access`/`promociones_access`/
  `cocina_access` — descartada: esos tres son *gates* de acceso a un módulo completo
  (feature flag binario, "lo tiene o no"); esta columna no gatea nada, siempre tiene un valor
  (uno de los dos), y solo cambia *qué texto* se muestra. Mezclarla en `PLAN_MODULES`
  (`app/core/plan_limits.py`) sería incorrecto: ese catálogo es consumido por
  `require_module_access`, que no aplica aquí (no hay ningún endpoint que bloquear, FR-010).

## 3. Por qué esta columna NO se expone en `GET /plan` (`PlanSummaryResponse`)

**Decisión**: `modalidad_pago_qr` se administra únicamente en los schemas/endpoints de Super
Admin (`app/api/v1/super_admin/schemas.py` + `plans_router.py`, mismo patrón que
`inventario_access`/`cocina_access`). **No** se agrega a `ModuleAccess`/`PlanSummaryResponse`
(`app/api/v1/plan/schemas.py`), que es lo que expone `GET /plan`, consumido por cualquier
usuario autenticado del tenant (`plan/router.py`: "cualquier rol, no solo ADMIN").

**Razón**: FR-004 exige que "ningún rol de administración del tenant [pueda] **consultar**,
editar o sobrescribir" esta modalidad — no solo que no pueda editarla. Si se agregara a
`PlanSummaryResponse`, cualquier usuario del tenant (incluido un mesero) podría leerla vía
`GET /plan`, violando la palabra "consulte" del FR literalmente. La única vía de lectura que
este spec autoriza es el cómputo interno, en el backend, del mensaje a mostrar al comensal
anónimo (FR-006) — nunca una respuesta que un rol de administración del tenant pueda invocar
para leer el valor crudo de la modalidad.

**Alternativas consideradas**: Exponerla en `GET /plan` y ocultarla solo en el frontend del
panel de administración del tenant — descartada: un administrador de tenant con herramientas
de red (DevTools, Postman) seguiría pudiendo "consultarla" contra el FR-004 literal; ocultar
en la capa de presentación no es "impedir que el sistema permita consultarla".

## 4. Cómo llega la modalidad al comensal sin pasar por un endpoint consultable por el tenant

**Decisión**: El valor no se transporta como tal — se transporta ya **computado** dentro del
pedido (`OrderResponse`, `app/api/v1/orders/schemas.py`), como un campo nuevo
`qr_payment_instruction_mode: Literal["PAY_AFTER_RECEIVING", "PAY_BEFORE_RECEIVING"] | None =
None`, poblado únicamente por los dos endpoints del comensal anónimo en
`app/api/v1/cart/router.py` (`submit_cart`, `my_orders`), con el mismo patrón ya usado para
`paid`/`pending_balance` en `orders/router.py:73-77` (atributo transitorio asignado sobre el
objeto ORM **después** de que el servicio lo construye, antes de serializar). Ningún otro
router que devuelva `OrderResponse` (POS, cocina, caja) asigna este atributo, así que queda en
su default `None` ahí — consistente con FR-013 ("no debe mostrarse... en POS, caja, terminal de
mesas o cocina"): el campo existe en el schema compartido pero esas pantallas ni lo piden ni lo
renderizan, y cuando viaja en su respuesta siempre es `null`.

El valor se calcula con una función nueva, pequeña, en `app/api/v1/plan/service.py` (que ya
hace `db.get(Plan, tenant.plan_id)` en `build_plan_summary`):
`get_qr_payment_instruction_mode(db: Session, tenant: Tenant) -> str`, que devuelve
`plan.modalidad_pago_qr` del plan vigente del tenant (FR-005: solo el plan del tenant
propietario de la orden, nunca de otro tenant). `cart/router.py` ya tiene `ctx.tenant`
disponible en ambos endpoints sin consulta adicional.

**Razón**: Cumple FR-006 (mensaje determinado por modalidad del plan + método de pago),
FR-005 (plan del tenant propietario, nunca otro) y FR-014 (se evalúa en el momento de mostrar
la instrucción, usando el plan vigente — no un valor persistido en la orden, sino calculado en
cada `GET`/`POST` de esos dos endpoints, así que un cambio de plan surte efecto en la próxima
lectura sin reprocesar nada).

**Alternativas consideradas**:
- Persistir la modalidad como columna de `CustomerOrder` en el momento de crear el pedido —
  descartada: congelaría la modalidad al momento de creación, contradiciendo FR-014 ("se
  refleja... sin alterar instrucciones ya mostradas para órdenes enviadas antes del cambio",
  que exige lo opuesto: la orden vieja no cambia, pero porque ya se mostró, no porque quedó
  grabada; una orden del mismo tenant que el comensal vuelva a abrir después de un cambio de
  plan vería la modalidad nueva bajo el diseño computado, nunca bajo uno persistido).
- Nuevo endpoint público `GET /cart/payment-instruction-mode` — descartada: una vuelta de red
  adicional sin necesidad, cuando el pedido que la pantalla de confirmación ya pide
  (`submitCart`/`myOrders`) es el vehículo natural.
- Calcularlo en el frontend a partir de algo expuesto por `resolveByToken` (menú) — descartada:
  obligaría a exponer la modalidad cruda en una respuesta pública sin sesión, y a mantenerla
  sincronizada entre dos fetches distintos (menú vs. pedido); el pedido ya es la fuente de
  verdad de qué mostrar en esta pantalla.

## 5. Dónde traduce el frontend `(modalidad, método de pago)` al texto exacto

**Decisión**: Se agrega una función pura nueva,
`qrPaymentInstructionMessage(mode, attempt)`, en
`pos-heladeria/src/app/modules/tables/order-status.util.ts` (mismo archivo que ya aloja
`orderStatusLabel`/`orderStatusClass`, mapeos puros consumidos por componentes de pedido), que
recibe `order.qr_payment_instruction_mode` y la forma de `current_payment_attempt`
(`is_cash`/`cash_amount`/`transfer_amount`) y devuelve el texto exacto de FR-007/FR-008.
`confirmation-step.component.ts` reemplaza sus tres literales de plantilla por una sola llamada
a esta función, con `mode` por defecto `'PAY_AFTER_RECEIVING'` si el backend aún no lo envía
(compatibilidad hacia atrás durante el despliegue, research.md Decisión 4 — nunca debería
ocurrir una vez desplegado el backend, pero el campo es opcional en el `interface`).

**Razón**: Evita cuatro `@if` encadenados dentro del template (dos modalidades × tres métodos)
y deja la combinatoria completa en un solo lugar testeable sin TestBed (función pura). Sigue el
patrón ya establecido por `order-status.util.ts` para este mismo componente, en vez de crear un
archivo de utilidades nuevo.

**Alternativas consideradas**: Un pipe de Angular — descartado: `orderStatusLabel`/
`orderStatusClass` ya resuelven el mismo tipo de necesidad como funciones simples invocadas
desde el componente, no como pipes; mantener el mismo estilo evita introducir dos convenciones
distintas para el mismo propósito dentro del mismo componente.

## 6. Forma de la UI de Super Admin para elegir la modalidad

**Decisión**: `plan-form.component.ts` gana un control nuevo tipo *radio*/*select* de dos
opciones ("Pago después de recibir" / "Pago antes de recibir") para
`formControlName="modalidad_pago_qr"`, en la sección donde hoy viven los checkboxes de módulo
(`inventario_access`/`promociones_access`/`cocina_access`, spec 149), pero como control
independiente — no un cuarto checkbox, porque no es un *access* binario sino una selección
excluyente de dos valores con nombre propio.

**Razón**: FR-001 ("exactamente uno de dos valores") se refleja mejor en un control de
selección única (radio/select) que en un checkbox, que normalmente comunica "activado/
desactivado" en vez de "cuál de estas dos opciones".

**Alternativas consideradas**: Checkbox "Pago antes de recibir" (boolean invertido) — misma
objeción que en la Decisión 2: oculta los nombres PAY_AFTER_RECEIVING/PAY_BEFORE_RECEIVING que
el spec usa como vocabulario de negocio, y es menos legible para quien administra el plan.

## 7. Migración Alembic

**Decisión**: Nueva revisión encadenada sobre el head actual (`019b97e8a107`, confirmado con
`alembic heads`), `op.add_column("plans", sa.Column("modalidad_pago_qr", sa.String(30),
nullable=False, server_default="PAY_AFTER_RECEIVING"), schema="shared")` +
`op.create_check_constraint("ck_plans_modalidad_pago_qr", "plans",
"modalidad_pago_qr IN ('PAY_AFTER_RECEIVING', 'PAY_BEFORE_RECEIVING')", schema="shared")`.
`downgrade()` hace `op.drop_constraint("ck_plans_modalidad_pago_qr", "plans",
schema="shared", type_="check")` seguido de `op.drop_column(...)` — **en ese orden** (el
memory de este proyecto registra que `drop_constraint` necesita el nombre completo con
prefijo, y que debe ejecutarse antes de tumbar la columna que referencia).

**Razón**: Sin backfill de datos necesario — el `server_default` resuelve el valor para los
planes ya existentes exactamente igual que la migración de referencia de `cocina_access`
(spec 149, Decisión 4 de ese research.md). El `CheckConstraint` se crea en una instrucción
separada (`create_check_constraint`, no inline en `add_column`) siguiendo el patrón ya usado
en otras migraciones de este proyecto que agregan una columna `String` con restricción cerrada.

## 8. Dónde se escribe la decisión de negocio (Principio II)

**Decisión**: Esta spec **no** requiere una entrada nueva en
`specs/000-reconocimiento/registro-de-anomalias.md`, porque no cambia ningún comportamiento ya
desplegado: el valor por defecto (`PAY_AFTER_RECEIVING`) es, por diseño (Assumptions del spec),
idéntico al comportamiento actual para todo plan existente — ningún tenant ve un mensaje
distinto al que ya ve hoy mientras el Super Admin no toque la columna nueva.

**Razón**: Mismo criterio que spec 149 aplicó a `cocina_access` (su `plan.md`, fila del
Principio II): agregar una columna con un default que reproduce el comportamiento actual no es
un cambio de comportamiento, es la introducción de una palanca nueva que, sin accionar, no
altera nada observable.
