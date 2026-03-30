//
//  VentaViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class VentaViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession
    private let tasaImpuesto = 0.15

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func crearVenta(cliente: Cliente) throws -> Venta {
        guard let empleado = employeeSession.empleadoActual else { throw TiendaError.sesionRequerida }
        let numero = try siguienteNumeroFactura()
        let venta = Venta(numero: numero, empleado: empleado, cliente: cliente)
        modelContext.insert(venta)
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Crear factura",
            detalle: "Se creo la factura \(numero) para el cliente \(cliente.nombre).",
            empleado: empleado,
            modelContext: modelContext
        )
        try modelContext.save()
        return venta
    }

    func guardarVenta(_ venta: Venta) throws {
        venta.numeroFactura = venta.numeroFactura.trimmingCharacters(in: .whitespacesAndNewlines)
        venta.recalcularTotales(tasaImpuesto: tasaImpuesto)
        guard !venta.numeroFactura.isEmpty else { throw TiendaError.datosIncompletos }

        let numeroFactura = venta.numeroFactura
        let ventaID = venta.persistentModelID
        let descriptor = FetchDescriptor<Venta>(
            predicate: #Predicate<Venta> { existente in
                existente.numeroFactura == numeroFactura && existente.persistentModelID != ventaID
            }
        )
        if try !modelContext.fetch(descriptor).isEmpty {
            throw TiendaError.facturaDuplicada
        }

        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Guardar factura",
            detalle: "Se guardo la factura \(venta.numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarVenta(_ venta: Venta) throws {
        guard venta.sePuedeEditar else { throw TiendaError.facturaNoEditable }

        for detalle in venta.detalles {
            if let producto = detalle.producto {
                let costoLote = costoPromedioPonderado(detalle: detalle)
                let movimiento = Kardex(
                    tipo: TipoMovimiento.entrada.rawValue,
                    cantidad: detalle.cantidad,
                    concepto: "Reversion venta \(venta.numeroFactura) - \(producto.nombre)",
                    costo: costoLote,
                    producto: producto,
                    empleado: employeeSession.empleadoActual
                )
                modelContext.insert(movimiento)
            }
        }

        let numeroFactura = venta.numeroFactura
        modelContext.delete(venta)
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Eliminar factura",
            detalle: "Se elimino la factura \(numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarVenta(_ venta: Venta) throws {
        guard venta.sePuedeEditar else { throw TiendaError.facturaNoEditable }

        venta.numeroFactura = venta.numeroFactura.trimmingCharacters(in: .whitespacesAndNewlines)
        venta.recalcularTotales(tasaImpuesto: tasaImpuesto)
        guard !venta.numeroFactura.isEmpty else { throw TiendaError.datosIncompletos }

        let numeroFactura = venta.numeroFactura
        let ventaID = venta.persistentModelID
        let descriptor = FetchDescriptor<Venta>(
            predicate: #Predicate<Venta> { existente in
                existente.numeroFactura == numeroFactura && existente.persistentModelID != ventaID
            }
        )
        if try !modelContext.fetch(descriptor).isEmpty {
            throw TiendaError.facturaDuplicada
        }

        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Modificar factura",
            detalle: "Se actualizo la factura \(venta.numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func emitirFactura(_ venta: Venta) throws {
        guard venta.estadoFactura == EstadoFactura.borrador.rawValue else { throw TiendaError.facturaNoEditable }
        guard !venta.detalles.isEmpty else { throw TiendaError.facturaSinDetalle }
        venta.recalcularTotales(tasaImpuesto: tasaImpuesto)
        venta.estadoFactura = EstadoFactura.emitida.rawValue
        try ContabilidadService.registrarVentaEmitida(
            venta: venta,
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Emitir factura",
            detalle: "Se emitio la factura \(venta.numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func marcarComoPagada(_ venta: Venta, metodoPago: String) throws {
        guard venta.estadoFactura == EstadoFactura.emitida.rawValue, venta.total > 0, !venta.detalles.isEmpty else { throw TiendaError.facturaSinDetalle }
        let metodo = metodoPago.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !metodo.isEmpty else { throw TiendaError.metodoPagoRequerido }
        venta.estadoFactura = EstadoFactura.pagada.rawValue
        venta.metodoPago = metodo
        venta.fechaPago = Date()
        try ContabilidadService.registrarCobroVenta(
            venta: venta,
            metodoPago: metodo,
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        if let cliente = venta.cliente {
            cliente.puntosAcumulados += Int(venta.total.rounded(.down))
        }
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Cobrar factura",
            detalle: "Se marco como pagada la factura \(venta.numeroFactura) con metodo \(metodo).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func anularFactura(_ venta: Venta, motivo: String) throws {
        guard venta.estadoFactura != EstadoFactura.pagada.rawValue, venta.estadoFactura != EstadoFactura.anulada.rawValue else { throw TiendaError.facturaNoEditable }
        let motivoLimpio = motivo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !motivoLimpio.isEmpty else { throw TiendaError.motivoAnulacionRequerido }

        if venta.estadoFactura == EstadoFactura.emitida.rawValue {
            try ContabilidadService.registrarAnulacionVenta(
                venta: venta,
                empleado: employeeSession.empleadoActual,
                modelContext: modelContext
            )
        }

        for detalle in venta.detalles {
            detalle.consumos.forEach { modelContext.delete($0) }
            if let producto = detalle.producto {
                let costoLote = costoPromedioPonderado(detalle: detalle)
                let movimiento = Kardex(
                    tipo: TipoMovimiento.entrada.rawValue,
                    cantidad: detalle.cantidad,
                    concepto: "Anulacion factura \(venta.numeroFactura) - \(producto.nombre)",
                    costo: costoLote,
                    producto: producto,
                    empleado: employeeSession.empleadoActual
                )
                modelContext.insert(movimiento)
            }
        }

        venta.estadoFactura = EstadoFactura.anulada.rawValue
        venta.motivoAnulacion = motivoLimpio
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Anular factura",
            detalle: "Se anulo la factura \(venta.numeroFactura). Motivo: \(motivoLimpio).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func siguienteNumeroFactura() throws -> String {
        let ventas = try modelContext.fetch(FetchDescriptor<Venta>())
        let maximo = ventas
            .compactMap { venta -> Int? in
                let componentes = venta.numeroFactura.split(separator: "-")
                guard let ultimo = componentes.last else { return nil }
                return Int(ultimo)
            }
            .max() ?? 0

        return String(format: "FAC-%06d", maximo + 1)
    }

    /// Calcula el costo promedio ponderado por lote de un detalle de venta
    private func costoPromedioPonderado(detalle: DetalleVenta) -> Double {
        let consumos = detalle.consumos
        guard !consumos.isEmpty else { return 0 }
        let costoTotal = consumos.reduce(0.0) { parcial, consumo in
            guard let lote = consumo.lote else { return parcial }
            let costoUnitario = lote.unidadesPorCaja > 0 ? lote.precioCompraCaja / lote.unidadesPorCaja : lote.precioCompraCaja
            return parcial + (consumo.cantidad * costoUnitario)
        }
        let cantidadTotal = consumos.reduce(0.0) { $0 + $1.cantidad }
        return cantidadTotal > 0 ? costoTotal / cantidadTotal : 0
    }
}
