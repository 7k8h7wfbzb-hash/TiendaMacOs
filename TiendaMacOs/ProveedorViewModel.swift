//
//  ProveedorViewModel.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 26/3/26.
//

import Foundation
import SwiftData
@Observable
class ProveedorViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession
    
    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }
    
    func crearProveedor(proveedor: Proveedor) throws {
        proveedor.nombre = proveedor.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        proveedor.ruc = proveedor.ruc.trimmingCharacters(in: .whitespacesAndNewlines)
        proveedor.contacto = proveedor.contacto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proveedor.nombre.isEmpty, !proveedor.ruc.isEmpty, !proveedor.contacto.isEmpty else { return }

        modelContext.insert(proveedor)
        OperacionLogger.registrar(
            modulo: "Proveedores",
            accion: "Crear proveedor",
            detalle: "Se registro el proveedor \(proveedor.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
    
    func eliminarProveedor(proveedor: Proveedor) throws {
        let nombre = proveedor.nombre
        modelContext.delete(proveedor)
        OperacionLogger.registrar(
            modulo: "Proveedores",
            accion: "Eliminar proveedor",
            detalle: "Se elimino el proveedor \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
