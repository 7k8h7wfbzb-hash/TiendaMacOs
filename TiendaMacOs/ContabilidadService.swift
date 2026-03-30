import Foundation
import SwiftData

enum ContabilidadService {
    private static let cuentaCaja = ("1101", "Caja", TipoCuenta.activo.rawValue)
    private static let cuentaBancos = ("1102", "Bancos", TipoCuenta.activo.rawValue)
    private static let cuentaPorCobrar = ("1103", "Cuentas por Cobrar", TipoCuenta.activo.rawValue)
    private static let cuentaInventario = ("1201", "Inventario Mercaderia", TipoCuenta.activo.rawValue)
    private static let cuentaPorPagar = ("2101", "Cuentas por Pagar", TipoCuenta.pasivo.rawValue)
    private static let cuentaIVAPorPagar = ("2102", "IVA por Pagar", TipoCuenta.pasivo.rawValue)
    private static let cuentaVentas = ("4101", "Ingresos por Ventas", TipoCuenta.ingreso.rawValue)
    private static let cuentaCostoVentas = ("5101", "Costo de Ventas", TipoCuenta.gasto.rawValue)

    // MARK: - Compra de inventario

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
            modulo: "Inventario",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: totalCompra, cuenta: inventario, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: totalCompra, cuenta: cuentasPorPagar, asiento: asiento))
    }

    // MARK: - Venta emitida

    static func registrarVentaEmitida(venta: Venta, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-EMITIDA-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let ingresos = try cuenta(cuentaVentas, modelContext: modelContext)
        let iva = try cuenta(cuentaIVAPorPagar, modelContext: modelContext)
        let costoVentasCta = try cuenta(cuentaCostoVentas, modelContext: modelContext)
        let inventario = try cuenta(cuentaInventario, modelContext: modelContext)
        let costo = costoVentaTotal(for: venta)

        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Emision de factura \(venta.numeroFactura)",
            modulo: "Ventas",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: venta.total, cuenta: cuentasPorCobrar, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: venta.subtotal, cuenta: ingresos, asiento: asiento))
        if venta.impuesto > 0 {
            modelContext.insert(DetalleAsientoContable(credito: venta.impuesto, cuenta: iva, asiento: asiento))
        }
        if costo > 0 {
            modelContext.insert(DetalleAsientoContable(debito: costo, cuenta: costoVentasCta, asiento: asiento))
            modelContext.insert(DetalleAsientoContable(credito: costo, cuenta: inventario, asiento: asiento))
        }
    }

    // MARK: - Cobro de venta

    static func registrarCobroVenta(venta: Venta, metodoPago: String, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-COBRO-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let destino = metodoPago == "Transferencia" ? cuentaBancos : cuentaCaja
        let cajaOBanco = try cuenta(destino, modelContext: modelContext)
        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Cobro de factura \(venta.numeroFactura) por \(metodoPago)",
            modulo: "Ventas",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: venta.total, cuenta: cajaOBanco, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: venta.total, cuenta: cuentasPorCobrar, asiento: asiento))
    }

    // MARK: - Anulacion de venta

    static func registrarAnulacionVenta(venta: Venta, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "VENTA-ANULADA-\(venta.numeroFactura)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let cuentasPorCobrar = try cuenta(cuentaPorCobrar, modelContext: modelContext)
        let ingresos = try cuenta(cuentaVentas, modelContext: modelContext)
        let iva = try cuenta(cuentaIVAPorPagar, modelContext: modelContext)
        let costoVentasCta = try cuenta(cuentaCostoVentas, modelContext: modelContext)
        let inventario = try cuenta(cuentaInventario, modelContext: modelContext)
        let costo = costoVentaTotal(for: venta)

        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Anulacion de factura \(venta.numeroFactura)",
            modulo: "Ventas",
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
            modelContext.insert(DetalleAsientoContable(credito: costo, cuenta: costoVentasCta, asiento: asiento))
        }
    }

    // MARK: - Pago a proveedor

    static func registrarPagoProveedor(lote: LoteProducto, metodoPago: String, empleado: Empleado?, modelContext: ModelContext) throws {
        let referencia = "PAGO-PROV-\(lote.idLote)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }

        let totalPago = max(valorCompraTotal(for: lote), 0)
        guard totalPago > 0 else { return }

        let destino = metodoPago == "Transferencia" ? cuentaBancos : cuentaCaja
        let cajaOBanco = try cuenta(destino, modelContext: modelContext)
        let cuentasPorPagar = try cuenta(cuentaPorPagar, modelContext: modelContext)
        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Pago a proveedor \(lote.proveedor?.nombre ?? "Sin proveedor") - Lote \(lote.idLote) por \(metodoPago)",
            modulo: "Proveedores",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: totalPago, cuenta: cuentasPorPagar, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: totalPago, cuenta: cajaOBanco, asiento: asiento))
    }

    // MARK: - Liquidacion IVA

    static func registrarLiquidacionIVA(monto: Double, empleado: Empleado?, modelContext: ModelContext) throws {
        let fechaRef = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let referencia = "LIQ-IVA-\(fechaRef)"
        guard try !asientoExiste(referencia: referencia, modelContext: modelContext) else { return }
        guard monto > 0 else { return }

        let iva = try cuenta(cuentaIVAPorPagar, modelContext: modelContext)
        let caja = try cuenta(cuentaCaja, modelContext: modelContext)
        let asiento = AsientoContable(
            referencia: referencia,
            concepto: "Liquidación de IVA por $\(String(format: "%.2f", monto))",
            modulo: "Contabilidad",
            empleado: empleado
        )

        modelContext.insert(asiento)
        modelContext.insert(DetalleAsientoContable(debito: monto, cuenta: iva, asiento: asiento))
        modelContext.insert(DetalleAsientoContable(credito: monto, cuenta: caja, asiento: asiento))
    }

    // MARK: - Verificar si un lote tiene pago registrado

    static func loteEstaPagado(lote: LoteProducto, modelContext: ModelContext) throws -> Bool {
        let referencia = "PAGO-PROV-\(lote.idLote)"
        return try asientoExiste(referencia: referencia, modelContext: modelContext)
    }

    // MARK: - Helpers privados

    static func cuenta(_ definicion: (String, String, String), modelContext: ModelContext) throws -> CuentaContable {
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
