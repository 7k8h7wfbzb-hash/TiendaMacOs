import Foundation
import SwiftData

enum ContabilidadService {
    private static let cuentaCaja = ("1101", "Caja", "ACTIVO")
    private static let cuentaBancos = ("1102", "Bancos", "ACTIVO")
    private static let cuentaPorCobrar = ("1103", "Cuentas por Cobrar", "ACTIVO")
    private static let cuentaInventario = ("1201", "Inventario Mercaderia", "ACTIVO")
    private static let cuentaPorPagar = ("2101", "Cuentas por Pagar", "PASIVO")
    private static let cuentaIVAPorPagar = ("2102", "IVA por Pagar", "PASIVO")
    private static let cuentaVentas = ("4101", "Ingresos por Ventas", "INGRESO")
    private static let cuentaCostoVentas = ("5101", "Costo de Ventas", "GASTO")

    static func registrarCompraInventario(lote: LoteProducto, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "COMPRA-\(lote.idLote)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let totalCompra = max(valorCompraTotal(for: lote), 0)
        guard totalCompra > 0 else { return }

        let inventario = try cuenta(cuentaInventario, modelContext: modelContext)
        let cuentasPorPagar = try cuenta(cuentaPorPagar, modelContext: modelContext)
        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Registro de compra de lote \(lote.idLote)",
            modulo: "Contabilidad",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: totalCompra, cuenta: inventario, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: totalCompra, cuenta: cuentasPorPagar, asiento: asiento))
    }

    static func registrarVentaEmitida(venta: Venta, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-EMITIDA-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let ingresos = try cuenta(cuentaVentas, modelContext: modelContext)
        let iva = try cuenta(cuentaIVAPorPagar, modelContext: modelContext)
        let costoVentas = try cuenta(cuentaCostoVentas, modelContext: modelContext)
        let inventario = try cuenta(cuentaInventario, modelContext: modelContext)
        let costo = costoVentaTotal(for: venta)

        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Emision de factura \(venta.numeroFactura)",
            modulo: "Contabilidad",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: venta.total, cuenta: cuentasPorCobrar, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: venta.subtotal, cuenta: ingresos, asiento: asiento))
        if venta.impuesto > 0 {
            modelContext.insert(DetalleAsientoContable(credito: venta.impuesto, cuenta: iva, asiento: asiento))
        }
        if costo > 0 {
            modelContext.insert(DetalleAsientoContable(debito: costo, cuenta: costoVentas, asiento: asiento))
            modelContext.insert(DetalleAsientoContable(credito: costo, cuenta: inventario, asiento: asiento))
        }
    }

    static func registrarCobroVenta(venta: Venta, metodoPago: String, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-COBRO-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let destino = metodoPago == "Transferencia" ? cuentaBancos : cuentaCaja
        let cajaOBanco = try cuenta(destino, modelContext: modelContext)
        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Cobro de factura \(venta.numeroFactura) por \(metodoPago)",
            modulo: "Contabilidad",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: venta.total, cuenta: cajaOBanco, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: venta.total, cuenta: cuentasPorCobrar, asiento: asiento))
    }

    static func registrarAnulacionVenta(venta: Venta, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-ANULADA-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let ingresos = try cuenta(cuentaVentas, modelContext: modelContext)
        let iva = try cuenta(cuentaIVAPorPagar, modelContext: modelContext)
        let costoVentas = try cuenta(cuentaCostoVentas, modelContext: modelContext)
        let inventario = try cuenta(cuentaInventario, modelContext: modelContext)
        let costo = costoVentaTotal(for: venta)

        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Anulacion de factura \(venta.numeroFactura)",
            modulo: "Contabilidad",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: venta.subtotal, cuenta: ingresos, asiento: asiento))
        if venta.impuesto > 0 {
            modelContext.insert(DetalleAsientoContable(debito: venta.impuesto, cuenta: iva, asiento: asiento))
        }
        modelContext.insert(DetalleAsientoContable(credito: venta.total, cuenta: cuentasPorCobrar, asiento: asiento))
        if costo > 0 {
            modelContext.insert(DetalleAsientoContable(debito: costo, cuenta: inventario, asiento: asiento))
            modelContext.insert(DetalleAsientoContable(credito: costo, cuenta: costoVentas, asiento: asiento))
        }
    }

    private static func cuenta(_ definicion: (String, String, String), modelContext: ModelContext) throws -> CuentaContable {
        let codigo = definicion.0
        let descriptor = FetchDescriptor<CuentaContable>(
            predicate: #Predicate<CuentaContable> { cuenta in
                cuenta.codigo == codigo
            }
        )
        if let existente = try modelContext.fetch(descriptor).first {
            return existente
        }

        let nuevaCuenta = CuentaContable(codigo: definicion.0, nombre: definicion.1, tipo: definicion.2)
        modelContext.insert(nuevaCuenta)
        return nuevaCuenta
    }

    private static func asientoExiste(referencia: String, modelContext: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<AsientoContable>(
            predicate: #Predicate<AsientoContable> { asiento in
                asiento.referencia == referencia
            }
        )
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private static func valorCompraTotal(for lote: LoteProducto) -> Double {
        let cajas = lote.cantidadCajas * lote.precioCompraCaja
        let precioUnitario = lote.unidadesPorCaja > 0 ? lote.precioCompraCaja / lote.unidadesPorCaja : lote.precioCompraCaja
        let sueltas = lote.unidadesSueltas * precioUnitario
        return cajas + sueltas
    }

    private static func costoVentaTotal(for venta: Venta) -> Double {
        venta.detalles.reduce(0) { acumulado, detalle in
            acumulado + detalle.consumos.reduce(0) { parcial, consumo in
                guard let lote = consumo.lote else { return parcial }
                return parcial + (consumo.cantidad * costoUnitario(for: lote))
            }
        }
    }

    private static func costoUnitario(for lote: LoteProducto) -> Double {
        guard lote.unidadesPorCaja > 0 else { return lote.precioCompraCaja }
        return lote.precioCompraCaja / lote.unidadesPorCaja
    }
}
