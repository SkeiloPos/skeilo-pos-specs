# Contrato: respuesta del servidor cuando el plan no incluye el módulo

**Spec**: [spec.md](../spec.md) (FR-005–FR-011, SC-001) · **Research**: [D1, D2, D3](../research.md)

## 1. Respuesta

Toda petición autenticada a una funcionalidad de un módulo que el plan vigente del tenant no incluye:

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "detail": "Tu plan actual no incluye el módulo de inventario.",
  "code": "MODULE_NOT_IN_PLAN",
  "module": "inventario"
}
```

| Campo | Tipo | Regla |
|---|---|---|
| `detail` | `string` | **Siempre string** y siempre presente (FR-007). Es el texto que los clientes ya leen hoy; no cambia su redacción: «Tu plan actual no incluye el módulo de `<inventario \| promociones>`.» |
| `code` | `string` | Constante `MODULE_NOT_IN_PLAN` |
| `module` | `string` | Clave del módulo requerido: `inventario` \| `promociones` (nunca `compras`) |

- Misma forma para **todos** los módulos (FR-008).
- No es el envelope de la spec 068 (`{error: {code, message, details}}`), que sigue limitado a `/api/v1/super-admin`.
- Sin cabeceras nuevas; las CORS vigentes bastan (el cuerpo es JSON legible por el front).

## 2. Precedencia de rechazos (de primero a último)

| Orden | Condición | Respuesta | ¿Cambia? |
|---|---|---|---|
| 1 | Sin credenciales válidas | 401 | No |
| 2 | **Plan vencido** (`plan_vence_en < ahora`) | 403 `"Tu plan venció. Debe renovarse para seguir usando el sistema."` — **sin** `code` | No (FR-009) |
| 3 | **Módulo no incluido** | 403 `MODULE_NOT_IN_PLAN` | **Nuevo `code`/`module`** (el `detail` no cambia) |
| 4 | Rol sin permiso (`require_tenant_admin`, etc.) | 403 con su propio texto, sin `code` | No (FR-010) |
| 5 | Validación del cuerpo / parámetros | 422 | No |

La dependencia del módulo se declara a nivel de router, por lo que corre **antes** de resolver el cuerpo y los parámetros:
una petición con cuerpo inválido a un módulo no incluido recibe 403, no 422, y no se ejecuta ninguna lectura ni escritura de
datos del negocio (FR-006, US2.2).

## 3. Garantías

1. **Sin acceso parcial** (FR-004): todas las rutas de [inventario-de-rutas.md](./inventario-de-rutas.md) aplican la misma
   dependencia; no hay rutas «sueltas» del módulo.
2. **Autoridad del servidor** (FR-005): el plan se lee en cada petición; no hay caché de tenant ni de plan. Un cambio de plan
   surte efecto en la **siguiente** petición (SC-003).
3. **Todos los roles** (FR-010): la dependencia exige solo un usuario autenticado del tenant; la restricción por rol que cada
   endpoint ya tenga se mantiene como paso 4.
4. **Compras sin indicador propio** (FR-004, US2.3): las 8 rutas de compras ya no exigen `compras_access`; con Inventario basta.
5. **Ventas, catálogo, pedidos, cobro y menú QR no se bloquean** (FR-011): no llevan la dependencia. Los campos de receta/stock
   de productos y adiciones siguen gobernados **a nivel de campo** con `ensure_module_access`/`has_module_access`
   (spec 064 y 123), que ahora también lanzan `ModuleNotInPlanError` cuando corresponde.

## 4. API interna (backend)

```python
# app/core/exceptions.py
class ModuleNotInPlanError(HTTPException):
    """403 con code/module (spec 141). `detail` sigue siendo string."""
    def __init__(self, module: str, label: str): ...

# app/core/plan_limits.py
PLAN_MODULES = ("inventario", "promociones")      # única fuente de verdad del catálogo (FR-001)

def require_module_access(module_key: str) -> Callable:   # valida module_key ∈ PLAN_MODULES al construirse
    ...                                                     # la función devuelta expone .module_key (para la prueba de rutas)
def ensure_module_access(db, tenant, module_key) -> None:   # vencido → HTTPException 403; sin módulo → ModuleNotInPlanError
def has_module_access(db, tenant, module_key) -> bool:      # no lanza; mismo catálogo
```

Handler: `@app.exception_handler(ModuleNotInPlanError)` serializa `{detail, code, module}` con `status_code=403`. Starlette resuelve el
handler por MRO, de modo que el handler genérico de `HTTPException` (y su comportamiento para el resto de rutas) no se toca.

## 5. Pruebas que fijan este contrato

| Prueba | Qué fija |
|---|---|
| `test_module_not_in_plan_error.py` | Cuerpo `{detail, code, module}`; `detail` string; orden de precedencia (vencido antes que módulo; módulo antes que rol); plan vencido **sin** `code`; cambio de plan entre dos llamadas |
| `test_module_route_inventory.py` | Las 43 rutas de `inventario` y las 7 de `promociones` llevan la dependencia correcta; una clave fuera de `PLAN_MODULES` falla al construir |
| E2E con `TestClient` (una ruta por módulo) | El handler real produce el cuerpo, con CORS y sin lecturas de datos del negocio |
