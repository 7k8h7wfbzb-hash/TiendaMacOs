//
//  DetalleVentaViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class DetalleVentaViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession
    private let tasaImpuesto = 0.15
    private let topeDescuentoTotalPorcentaje = 30.0

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarDetalle(_ detalle: DetalleVenta) throws {
        guard detalle.cantidad > 0,
              detalle.precioUnitarioSnapshot >= 0,
              let producto = detalle.producto,
              let venta = detalle.venta,
              venta.sePuedeEditar,
              producto.stockActual >= detalle.cantidad
        else { throw TiendaError.stockInsuficiente }

        let ventaID = venta.persistentModelID
        let productoID = producto.persistentModelID
        let descriptor = FetchDescriptor<DetalleVenta>(
            predicate: #Predicate<DetalleVenta> { existente in
                existente.venta?.persistentModelID == ventaID &&
                existente.producto?.persistentModelID == productoID
            }
        )

        let cantidadNueva = detalle.cantidad
        let precioBase = detalle.precioUnitarioSnapshot
        let (precioFinal, descuentoPromo, descuentoFidelidad, nombrePromocion) = calcularPrecioFinal(
            precioBase: precioBase,
            producto: producto,
            cliente: venta.cliente
        )
        detalle.precioBaseSnapshot = precioBase
        detalle.descuentoPromocionUnitario = descuentoPromo
        detalle.descuentoFidelidadUnitario = descuentoFidelidad
        detalle.promocionAplicadaNombre = nombrePromocion
        detalle.precioUnitarioSnapshot = precioFinal

        if let existente = try modelContext.fetch(descriptor).first {
            existente.cantidad += cantidadNueva
            existente.precioBaseSnapshot = precioBase
            existente.precioUnitarioSnapshot = precioFinal
            existente.descuentoPromocionUnitario = descuentoPromo
            existente.descuentoFidelidadUnitario = descuentoFidelidad
            existente.promocionAplicadaNombre = nombrePromocion
            try registrarConsumoFEFO(cantidad: cantidadNueva, para: producto, en: existente)
        } else {
            modelContext.insert(detalle)
            try registrarConsumoFEFO(cantidad: cantidadNueva, para: producto, en: detalle)
        }

        let movimiento = Kardex(
            tipo: "SALIDA",
            cantidad: cantidadNueva,
            concepto: "Venta \(venta.numeroFactura) - \(producto.nombre)",
            costo: detalle.precioUnitarioSnapshot,
            producto: producto,
            empleado: employeeSession.empleadoActual
        )
        modelContext.insert(movimiento)
        venta.recalcularTotales(tasaImpuesto: tasaImpuesto)
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Agregar detalle",
            detalle: "Se agregaron \(String(format: "%.0f", cantidadNueva)) unidades de \(producto.nombre) a la factura \(venta.numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )

        try modelContext.save()
    }

    func calcularPrecioFinal(precioBase: Double, producto: Producto, cliente: Cliente?) -> (precioFinal: Double, descuentoPromocion: Double, descuentoFidelidad: Double, nombrePromocion: String?) {
        let promocionesVigentes = producto.promociones.filter { $0.estaVigente() }
        let mejorPromocion = promocionesVigentes.max { lhs, rhs in
            lhs.descuentoUnitario(precioBase: precioBase) < rhs.descuentoUnitario(precioBase: precioBase)
        }

        let descuentoPromocion = mejorPromocion?.descuentoUnitario(precioBase: precioBase) ?? 0
        let baseTrasPromo = max(precioBase - descuentoPromocion, 0)
        let descuentoFidelidadBase: Double
        if let mejorPromocion, !mejorPromocion.combinableConFidelidad {
            descuentoFidelidadBase = 0
        } else {
            descuentoFidelidadBase = cliente.map { baseTrasPromo * ($0.descuentoFidelidad / 100) } ?? 0
        }

        let topeDescuentoTotal = max(precioBase * (topeDescuentoTotalPorcentaje / 100), 0)
        let descuentoTotalPrevio = descuentoPromocion + descuentoFidelidadBase
        let descuentoFidelidad: Double
        if descuentoTotalPrevio > topeDescuentoTotal {
            let margenDisponibleParaFidelidad = max(topeDescuentoTotal - descuentoPromocion, 0)
            descuentoFidelidad = min(descuentoFidelidadBase, margenDisponibleParaFidelidad)
        } else {
            descuentoFidelidad = descuentoFidelidadBase
        }

        let precioFinal = max(precioBase - descuentoPromocion - descuentoFidelidad, 0)

        return (
            precioFinal,
            descuentoPromocion,
            descuentoFidelidad,
            mejorPromocion?.nombre
        )
    }

    func eliminarDetalle(_ detalle: DetalleVenta) throws {
        if let producto = detalle.producto, let venta = detalle.venta {
            guard venta.sePuedeEditar else { throw TiendaError.facturaNoEditable }

            let movimiento = Kardex(
                tipo: "ENTRADA",
                cantidad: detalle.cantidad,
                concepto: "Reversion detalle \(venta.numeroFactura) - \(producto.nombre)",
                costo: detalle.precioUnitarioSnapshot,
                producto: producto,
                empleado: employeeSession.empleadoActual
            )
            modelContext.insert(movimiento)
            OperacionLogger.registrar(
                modulo: "Ventas",
                accion: "Eliminar detalle",
                detalle: "Se elimino el detalle de \(producto.nombre) en la factura \(venta.numeroFactura).",
                empleado: employeeSession.empleadoActual,
                modelContext: modelContext
            )
        }

        modelContext.delete(detalle)
        detalle.venta?.recalcularTotales(tasaImpuesto: tasaImpuesto)
        try modelContext.save()
    }

    func modificarDetalle(_ detalle: DetalleVenta) throws {
        guard detalle.cantidad > 0,
              detalle.precioUnitarioSnapshot >= 0,
              let venta = detalle.venta,
              venta.sePuedeEditar
        else { throw TiendaError.facturaNoEditable }

        venta.recalcularTotales(tasaImpuesto: tasaImpuesto)
        OperacionLogger.registrar(
            modulo: "Ventas",
            accion: "Modificar detalle",
            detalle: "Se actualizo un detalle de la factura \(venta.numeroFactura).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    private func registrarConsumoFEFO(cantidad: Double, para producto: Producto, en detalle: DetalleVenta) throws {
        var restante = cantidad
        let lotesOrdenados = producto.lotes
            .filter { $0.estadoLote == "VIGENTE" || $0.estadoLote == "PROXIMO" }
            .sorted { lhs, rhs in
                switch (lhs.fechaCaducidad, rhs.fechaCaducidad) {
                case let (izquierda?, derecha?):
                    if izquierda != derecha {
                        return izquierda < derecha
                    }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                return lhs.fechaIngreso < rhs.fechaIngreso
            }

        for lote in lotesOrdenados where restante > 0 {
            let disponible = lote.unidadesDisponibles
            guard disponible > 0 else { continue }

            let consumo = min(disponible, restante)
            modelContext.insert(ConsumoLote(cantidad: consumo, lote: lote, detalleVenta: detalle))
            restante -= consumo
        }

        if restante > 0 {
            throw TiendaError.stockInsuficiente
        }
    }
}
