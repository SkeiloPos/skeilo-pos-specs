# Contrato — Zona horaria del tenant (FR-008, FR-010, FR-011, FR-016)

Todos los cambios de este contrato son **aditivos**: ningún cliente actual se rompe.

## 1. Alta de tenant — `POST /api/v1/super-admin/tenants`

Solo Super Admin (`get_current_super_admin`). Cuerpo `TenantCreateWithUser`:

| Campo | Tipo | Obligatorio | Nuevo |
|---|---|---|---|
| `tenant_name`, `schema_name`, `host`, `name`, `email`, `plan_id`, `ciclo_facturacion` | los de hoy | los de hoy | no |
| **`timezone`** | `string` IANA | **no** (API/script) | **sí** |

- Ausente o `null` ⇒ el tenant nace con `America/Bogota` (`server_default`). **No se rechaza.**
- Presente pero inválido (regla de [data-model.md §1](../data-model.md)) ⇒ **422** con el formato de error del
  módulo Super Admin, **antes** de crear nada (el validador de Pydantic corre antes de `tenant_create`).
- Los alias heredados (`Asia/Calcutta`, `America/Buenos_Aires`) pasan el validador de Python pero no existen en
  `pg_timezone_names`: el disparador los rechaza (`22023`). `tenant_create` —que hoy convierte sus errores inesperados en un
  500 genérico— captura ese `DataError` en una rama propia y responde **422** con el mismo formato de error del módulo; no
  queda nada creado (el `flush` del `Tenant` ocurre antes de `CreateSchema`, dentro de la misma transacción).
- La **pantalla** exige una zona de la lista curada, sin valor preseleccionado, y la envía siempre.

`tenant_create(…, timezone: str | None = None)`: con valor, se asigna al `Tenant` antes del `flush` (el `@validates`
actúa); con `None`, no se asigna y rige el `server_default`.

## 2. Lista de tenants — `GET /api/v1/super-admin/tenants`

`TenantResponse` gana **`timezone: string`** (IANA del tenant de esa fila). El frontend muestra `plan_vence_en`
con `tenantDate` usando ese valor (el Super Admin y el negocio ven el mismo día).

## 3. Menú público del comensal — `GET /api/v1/menu/qr-token/{token}`

`business` (`MenuBusinessResponse`) gana **`timezone: string`**. El comensal es anónimo y no puede llamar a
`GET /tenant`; esta es la única vía por la que su navegador conoce la zona del negocio. El frontend la usa para la hora
de los pedidos (`public-menu.component.ts::orderTime`).

`GET /api/v1/tenant` ya devuelve `timezone` (spec 030) y no cambia.

## 4. Correo — `construir_correo_contrasena_cambiada`

```python
construir_correo_contrasena_cambiada(
    *, correo, momento, url_ingreso, es_super_admin, nombre_negocio=None,
    zona_horaria: str | None = None,   # NUEVO. None ⇒ America/Bogota
)
```

| Caso | Texto de la hora |
|---|---|
| Tenant en Bogotá, o usuario sin tenant (Super Admin) | `02/10/2026 · 04:06 p. m. (hora de Colombia)` — **idéntico al actual** |
| Tenant en una zona de la lista curada | `… (hora de Ciudad de México)` / `Lima` / `Santiago` / `Buenos Aires` / `Madrid` / `Tokio` |
| Tenant en una zona válida fuera de la lista | `… (UTC−3)` · `… (UTC+5:30)` |

`formatear_fecha_hora_colombia(momento)` **se conserva** (envoltorio de Bogotá) porque tres archivos de pruebas de
caracterización lo llaman y fijan su salida exacta (Principio III); se agrega `formatear_fecha_hora(momento, zona)`.
`_dispatch_password_changed_email` pasa `user.tenant.timezone` si `user.tenant_id is not None`.

Las otras dos plantillas (invitación, restablecimiento) **no muestran una hora absoluta** y no cambian.

## 5. Cambio de zona de un tenant existente — `python -m app.scripts.set_tenant_timezone` (FR-016)

Sigue siendo el único camino (no hay pantalla). Cambios:

- Usa el mismo `validate_iana_timezone`; un valor inválido termina con error y **no** persiste nada.
- Imprime **antes de escribir** una advertencia con la zona anterior y la nueva: *«Los instantes guardados no cambian,
  pero el historial se reinterpretará en la nueva zona: límites de día, reportes, promociones y fechas mostradas
  cambiarán de hora local.»*
- Si la base de datos rechaza el valor (disparador), informa el mensaje del motor.

## 6. Lista curada de zonas

Ver [data-model.md §3](../data-model.md). Definida en `app/core/timezone.py::ZONAS_CURADAS` y en
`pos-heladeria/src/app/shared/tenant-timezones.ts`; una prueba por lado compara con el mismo literal (precedente: spec
091, subdominios reservados).
