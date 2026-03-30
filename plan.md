# Plan: Modulo de Contabilidad Completo

## Estado Actual
- 3 modelos (CuentaContable, AsientoContable, DetalleAsientoContable)
- 4 asientos automaticos en ContabilidadService (compra, venta, cobro, anulacion)
- Vista solo lectura con stats, grafico y tablas basicas
- 8 cuentas hardcodeadas, sin CRUD

## Archivos a Modificar/Crear

### 1. Empleado.swift — Agregar enum TipoCuenta
```
enum TipoCuenta: String, Codable, CaseIterable {
    case activo = "ACTIVO"
    case pasivo = "PASIVO"
    case patrimonio = "PATRIMONIO"
    case ingreso = "INGRESO"
    case gasto = "GASTO"
}
```

### 2. ContabilidadModels.swift — Mejorar CuentaContable
- Agregar `activa: Bool = true` para desactivar cuentas sin eliminar
- saldoActual ya corregido para tipo natural

### 3. TiendaError.swift — Nuevos casos contables
- `asientoDesbalanceado` — debitos != creditos
- `cuentaInactiva` — se intenta usar una cuenta inactiva
- `cuentaConMovimientos` — no se puede eliminar una cuenta con movimientos
- `periodoInvalido` — rango de fechas invalido

### 4. ContabilidadViewModel.swift — NUEVO ARCHIVO
ViewModel con ModelContext + EmployeeSession para:
- `crearCuenta(codigo, nombre, tipo)` — validar codigo unico, insertar
- `modificarCuenta(cuenta)` — actualizar campos
- `toggleActivaCuenta(cuenta)` — activar/desactivar
- `eliminarCuenta(cuenta)` — solo si no tiene movimientos
- `crearAsientoManual(concepto, modulo, lineas)` — validar balance, insertar
- `eliminarAsiento(asiento)` — solo manuales (modulo == "Manual")
- `registrarPagoProveedor(lote, metodoPago)` — llama ContabilidadService
- `registrarLiquidacionIVA(monto)` — llama ContabilidadService

### 5. ContabilidadService.swift — 2 metodos nuevos
- `registrarPagoProveedor(lote, metodoPago, empleado, modelContext)`
  Dr CuentasPorPagar / Cr Caja o Bancos
- `registrarLiquidacionIVA(monto, empleado, modelContext)`
  Dr IVA por Pagar / Cr Caja

### 6. ContabilidadView.swift — REESCRITURA COMPLETA
Picker de seccion en el encabezado con 7 secciones internas:

a) **Resumen** — Dashboard mejorado: stats, grafico de saldos,
   grafico de ingresos vs gastos, chips de cobertura

b) **Plan de Cuentas** — CRUD completo:
   - Formulario: codigo, nombre, tipo (Picker), activa (Toggle)
   - Tabla con todas las cuentas, indicador de activa/inactiva
   - Boton eliminar (solo si sin movimientos)

c) **Diario General** — Journal con filtros:
   - DatePicker desde/hasta para filtrar rango
   - Campo de busqueda por referencia/concepto
   - Formulario para asiento manual (concepto + lineas dinamicas)
   - Lista de asientos con detalles expandibles

d) **Libro Mayor** — Ledger por cuenta:
   - Picker para seleccionar cuenta
   - DatePicker desde/hasta
   - Tabla tipo T: fecha, concepto, debito, credito, saldo acumulado
   - Saldo final al pie

e) **Balance de Comprobacion** — Trial balance:
   - DatePicker corte
   - Tabla: codigo, cuenta, debitos, creditos, saldo deudor, saldo acreedor
   - Totales al pie (deben cuadrar)

f) **Estado de Resultados** — Income Statement:
   - DatePicker desde/hasta
   - Seccion INGRESOS (cuentas tipo INGRESO)
   - Seccion GASTOS (cuentas tipo GASTO)
   - Linea final: Utilidad/Perdida = Ingresos - Gastos

g) **Balance General** — Balance Sheet:
   - DatePicker corte
   - ACTIVOS (cuentas tipo ACTIVO)
   - PASIVOS (cuentas tipo PASIVO)
   - PATRIMONIO (cuentas tipo PATRIMONIO)
   - Ecuacion: Activo = Pasivo + Patrimonio

### 7. CuentasPorPagarView.swift — NUEVO ARCHIVO
Similar a CuentasPorCobrarView pero para proveedores:
- Query de LoteProducto que tengan asiento COMPRA pero no asiento PAGO
- Tabla: proveedor, lote, monto, dias pendientes
- Boton para registrar pago (abre Picker de metodo de pago)
- Requiere ContabilidadViewModel

### 8. DashboardView.swift — Agregar seccion
- Nuevo case `cuentasPorPagar` en SeccionDashboard
- Icono, titulo, subtitulo, color
- Route a CuentasPorPagarView en detailContent

## Orden de Implementacion
1. Empleado.swift (enum TipoCuenta)
2. ContabilidadModels.swift (campo activa)
3. TiendaError.swift (casos contables)
4. ContabilidadService.swift (2 metodos nuevos)
5. ContabilidadViewModel.swift (nuevo)
6. ContabilidadView.swift (reescritura completa)
7. CuentasPorPagarView.swift (nuevo)
8. DashboardView.swift (nueva seccion)
9. Build + verificar
