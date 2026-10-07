# Contrato: `GET /bootstrap`

**Spec**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md) |
**Research**: [../research.md](../research.md) §§ 1, 2, 3, 6

Router nuevo `app/api/v1/bootstrap/router.py`, montado con el mismo prefijo `/api/v1` que el resto
(`app/main.py`). A diferencia de `/tenant`, `/plan` y `/notifications` — que exigen un tenant
resuelto (`Depends(get_tenant)`, `404` si el host no mapea a ninguno) — este endpoint usa
`get_authenticated_user` (resuelve al usuario sin exigir tenant) y una dependencia nueva
`get_optional_tenant` (igual lookup que `get_tenant`, pero devuelve `None` en vez de `404`).

## `GET /bootstrap`

Sin parámetros de query ni de path. El tenant sale, como en todo el dominio, de
`X-Tenant-Host` — nunca de un parámetro que el cliente controle.

**Respuesta `200`** — único código de respuesta de este endpoint (más allá del `401` estándar de
autenticación, idéntico al de cualquier otro endpoint de la API):

### Caso 1 — staff/administrador de un tenant, todo disponible (US1)

```json
{
  "tenant": {
    "id": 7,
    "name": "Heladería Central",
    "host": "central.skeilopos.com",
    "logo_url": null,
    "receipt_message": null,
    "invoice_prefix": "FC",
    "timezone": "America/Bogota"
  },
  "plan": {
    "plan_name": "Básico",
    "ciclo_facturacion": "mensual",
    "plan_vence_en": "2026-09-24T00:00:00Z",
    "vencido": false,
    "resources": {
      "mesas": { "used": 4, "limit": 5 },
      "cajas": { "used": 1, "limit": 1 },
      "usuarios": { "used": 3, "limit": 3 },
      "productos": { "used": 40, "limit": null },
      "metodos_pago_activos": { "used": 1, "limit": 2 }
    },
    "modules": { "inventario": false, "compras": false, "promociones": true }
  },
  "notifications": {
    "items": [
      {
        "id": "uuid",
        "event_type": "order.created",
        "related_entity_type": "customer_order",
        "related_entity_id": "uuid",
        "payload": { "table_number": 4, "customer_name": "...", "items_count": 3, "total": "45000" },
        "created_at": "2026-09-07T18:30:00Z",
        "attended_at": null,
        "attended_by_user_id": null
      }
    ],
    "total": 42,
    "page": 1,
    "size": 20
  }
}
```

Cada bloque es **exactamente** el body que hoy entrega su endpoint individual
(`GET /tenant`, `GET /plan`, `GET /notifications?page=1&size=20`) — ver sus propios contratos
enlazados en `data-model.md`. No hay ningún campo nuevo ni renombrado.

### Caso 2 — Super Admin sin tenant ni plan (US2, FR-007)

```json
{ "tenant": null, "plan": null, "notifications": null }
```

`200`, no `404`. Los 3 bloques en `null` porque `get_optional_tenant` no resolvió ningún tenant
(research.md Decisión 2) — `notifications` también queda `null` aquí, no solo `tenant`/`plan`,
porque es una fuente tenant-scoped igual que las otras dos (research.md Decisión 6).

### Caso 3 — degradación parcial granular (US3, FR-006)

Ejemplo con `notifications` fallando mientras `tenant`/`plan` responden bien:

```json
{
  "tenant": { "id": 7, "name": "Heladería Central", "...": "..." },
  "plan": { "plan_name": "Básico", "...": "..." },
  "notifications": null
}
```

`200` igual que el caso 1 — ningún campo indica "hubo un error parcial" (la spec no lo pide; el
frontend ya trata un bloque `null` igual que su estado por defecto, sin distinguir "nunca se pidió"
de "se pidió y falló").

### Caso 4 — fallo total (US3, FR-005)

No hay una forma de "fallo total" propia de este contrato: si la petición no llega a responder
(timeout, caída de red) o el servidor responde `5xx` antes de construir el body, es un fallo de
transporte/infraestructura, no una respuesta de este endpoint. El comportamiento exigido por
FR-005 (panel usable con los valores por defecto actuales, sin reintentar automáticamente las
peticiones individuales) es responsabilidad del **frontend** (`BootstrapService.load()`, ver
`research.md` Decisión 7/8), no de este contrato.

## Aislamiento entre tenants

Igual que `/tenant`, `/plan` y `/notifications`: ningún parámetro de tenant en query/body/path, el
tenant sale siempre de `X-Tenant-Host` resuelto del lado del servidor. Las consultas de los
bloques `plan`/`notifications` corren bajo el `schema_translate_map` del tenant resuelto — mismo
mecanismo de aislamiento que ya protege cualquier otro recurso tenant-scoped (ver
`077-notificaciones-tiempo-real/contracts/notifications-api.md` § Aislamiento).

## Compatibilidad

Endpoint 100% nuevo y aditivo — no reemplaza ni deprecated a `GET /tenant`, `GET /plan` ni
`GET /notifications`, que siguen existiendo sin cambios de contrato (FR-003) para los refrescos
puntuales posteriores al arranque (p. ej. tras editar en "Ajustes").
