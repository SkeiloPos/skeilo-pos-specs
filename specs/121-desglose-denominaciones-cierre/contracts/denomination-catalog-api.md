# Contrato — Catálogo de denominaciones del tenant

**Spec**: [../spec.md](../spec.md) (FR-009 a FR-013) · **Data model**: [../data-model.md](../data-model.md) §1 ·
**Research**: [../research.md](../research.md) R1, R2, R7

Endpoint **nuevo y de solo lectura**. La administración del catálogo (crear/editar/activar/
desactivar) queda fuera de esta spec (FR-012).

## `GET /api/v1/cash/denominations`

Lista las denominaciones permitidas del tenant, **de mayor a menor valor**.

- **Autenticación**: `get_current_user` (el mismo nivel que cerrar el turno).
- **Query**: ninguno.
- **Escritura**: ninguna. No existe `POST`/`PUT`/`DELETE` para el catálogo.

### Respuesta `200` — `list[DenominationCatalogItem]`

```jsonc
[
  { "denomination": "100000.00", "kind": "billete" },
  { "denomination": "50000.00",  "kind": "billete" },
  { "denomination": "20000.00",  "kind": "billete" },
  { "denomination": "10000.00",  "kind": "billete" },
  { "denomination": "5000.00",   "kind": "billete" },
  { "denomination": "2000.00",   "kind": "billete" },
  { "denomination": "1000.00",   "kind": "moneda" },
  { "denomination": "500.00",    "kind": "moneda" },
  { "denomination": "200.00",    "kind": "moneda" },
  { "denomination": "100.00",    "kind": "moneda" },
  { "denomination": "50.00",     "kind": "moneda" }
]
```

| Campo | Tipo | Notas |
|-------|------|-------|
| `denomination` | cadena decimal | Valor nominal; único en el catálogo |
| `kind` | `"billete"` \| `"moneda"` | El cliente **no** lo envía al cerrar; el servidor lo toma de aquí |

Un tenant existente o nuevo obtiene este mismo catálogo por defecto sin configurar nada (FR-012,
US3-5).

### Errores

| Código | Cuándo |
|--------|--------|
| `401` | Sin sesión (comportamiento estándar de `get_current_user`) |
| `403` | Rol MESERO: su lista *default-deny* no incluye esta ruta, igual que el cierre de turno |

Un catálogo **vacío** devuelve `200` con `[]`. No es un error del servidor: la pantalla lo trata
como «no se puede contar» (FR-013) y bloquea la confirmación.

## Consumo desde la pantalla (resumen de comportamiento)

- Se consulta **cada vez que se abre** el modal de arqueo, sin caché entre aperturas.
- `200` con ≥ 1 elemento → una fila por denominación, con su tipo.
- Error de red/servidor, o `200` con `[]` → confirmar deshabilitado + mensaje + «Reintentar»; no se
  envía ninguna petición de cierre (US3-6).
