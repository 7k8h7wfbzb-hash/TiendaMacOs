//
//  LoteProductoViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class LoteProductoViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarLote(_ lote: LoteProducto) throws {
        guard lote.cantidadCajas >= 0,
              lote.unidadesPorCaja >= 0,
              lote.unidadesSueltas >= 0,
              lote.precioCompraCaja >= 0,
              lote.precioVentaSugerido >= 0,
              !lote.tipoEmpaque.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        lote.tipoEmpaque = lote.tipoEmpaque.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(lote)

        if let producto = lote.producto {
            let movimiento = Kardex(
                tipo: "ENTRADA",
                cantidad: lote.totalUnidades,
                concepto: "Ingreso de lote \(lote.idLote) - \(lote.proveedor?.nombre ?? "Proveedor sin nombre")",
                costo: lote.precioCompraCaja,
                producto: producto,
                empleado: employeeSession.empleadoActual
            )
            modelContext.insert(movimiento)
        }
        
        OperacionLogger.registrar(
            modulo: "Lotes",
            accion: "Crear lote",
            detalle: "Se registro el lote \(lote.idLote) del producto \(lote.producto?.nombre ?? "Sin producto").",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )

        try ContabilidadService.registrarCompraInventario(
            lote: lote,
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func devolverLoteAProveedor(_ lote: LoteProducto, motivo: String) throws {
        let motivoLimpio = motivo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !motivoLimpio.isEmpty else { throw TiendaError.motivoDevolucionProveedorRequerido }
        guard lote.sePuedeDevolverAProveedor else { throw TiendaError.loteNoDisponibleParaDevolucion }

        lote.fechaDevolucionProveedor = Date()
        lote.motivoDevolucionProveedor = motivoLimpio

        if let producto = lote.producto {
            let movimiento = Kardex(
                tipo: "SALIDA",
                cantidad: lote.totalUnidades,
                concepto: "Devolucion a proveedor del lote \(lote.idLote) - \(lote.proveedor?.nombre ?? "Proveedor sin nombre")",
                costo: lote.precioCompraCaja,
                producto: producto,
                empleado: employeeSession.empleadoActual
            )
            modelContext.insert(movimiento)
        }

        OperacionLogger.registrar(
            modulo: "Lotes",
            accion: "Devolver lote a proveedor",
            detalle: "Se devolvio el lote \(lote.idLote) por motivo: \(motivoLimpio).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarLote(_ lote: LoteProducto) throws {
        if let producto = lote.producto {
            guard lote.consumos.isEmpty, producto.stockActual >= lote.totalUnidades else { throw TiendaError.loteConConsumos }

            let movimiento = Kardex(
                tipo: "SALIDA",
                cantidad: lote.totalUnidades,
                concepto: "Reversion de lote \(lote.idLote) - \(lote.proveedor?.nombre ?? "Proveedor sin nombre")",
                costo: lote.precioCompraCaja,
                producto: producto,
                empleado: employeeSession.empleadoActual
            )
            modelContext.insert(movimiento)
        }

        let idLote = lote.idLote
        modelContext.delete(lote)
        OperacionLogger.registrar(
            modulo: "Lotes",
            accion: "Eliminar lote",
            detalle: "Se elimino el lote \(idLote).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarLote(_ lote: LoteProducto) throws {
        lote.tipoEmpaque = lote.tipoEmpaque.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lote.tipoEmpaque.isEmpty else { return }
        OperacionLogger.registrar(
            modulo: "Lotes",
            accion: "Modificar lote",
            detalle: "Se actualizo el lote \(lote.idLote).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
