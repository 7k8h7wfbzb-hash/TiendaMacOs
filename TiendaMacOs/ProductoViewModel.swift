//
//  ProductoViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class ProductoViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarProducto(producto: Producto) throws {
        producto.nombre = producto.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.codigoProducto = producto.codigoProducto.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.marca = producto.marca.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.unidadMedida = producto.unidadMedida.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.detalleProducto = producto.detalleProducto.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.estadoFisico = producto.estadoFisico.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !producto.nombre.isEmpty, !producto.estadoFisico.isEmpty, !producto.unidadMedida.isEmpty else { return }

        modelContext.insert(producto)
        OperacionLogger.registrar(
            modulo: "Productos",
            accion: "Crear producto",
            detalle: "Se registro el producto \(producto.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarProducto(producto: Producto) throws {
        guard producto.movimientosKardex.isEmpty else { throw TiendaError.productoConHistorial }
        let nombre = producto.nombre
        modelContext.delete(producto)
        OperacionLogger.registrar(
            modulo: "Productos",
            accion: "Eliminar producto",
            detalle: "Se elimino el producto \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarProducto(producto: Producto) throws {
        producto.nombre = producto.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.codigoProducto = producto.codigoProducto.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.marca = producto.marca.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.unidadMedida = producto.unidadMedida.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.detalleProducto = producto.detalleProducto.trimmingCharacters(in: .whitespacesAndNewlines)
        producto.estadoFisico = producto.estadoFisico.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !producto.nombre.isEmpty, !producto.estadoFisico.isEmpty, !producto.unidadMedida.isEmpty else { return }

        OperacionLogger.registrar(
            modulo: "Productos",
            accion: "Modificar producto",
            detalle: "Se actualizo el producto \(producto.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
