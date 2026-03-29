//
//  EmpleadoViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class EmpleadoViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarEmpleado(empleado: Empleado) throws {
        empleado.nombre = empleado.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        empleado.cargo = empleado.cargo.trimmingCharacters(in: .whitespacesAndNewlines)
        empleado.usuario = empleado.usuario.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        empleado.pinAcceso = empleado.pinAcceso.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !empleado.nombre.isEmpty, !empleado.cargo.isEmpty, !empleado.usuario.isEmpty, !empleado.pinAcceso.isEmpty else {
            throw TiendaError.credencialesIncompletas
        }

        modelContext.insert(empleado)
        OperacionLogger.registrar(
            modulo: "Empleados",
            accion: "Crear empleado",
            detalle: "Se registro el empleado \(empleado.nombre) con usuario \(empleado.usuario).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarEmpleado(empleado: Empleado) throws {
        if employeeSession.empleadoActual?.persistentModelID == empleado.persistentModelID {
            throw TiendaError.empleadoEnSesion
        }
        guard empleado.ventas.isEmpty else { throw TiendaError.empleadoConVentas }
        let nombre = empleado.nombre
        modelContext.delete(empleado)
        OperacionLogger.registrar(
            modulo: "Empleados",
            accion: "Eliminar empleado",
            detalle: "Se elimino el empleado \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarEmpleado(empleado: Empleado) throws {
        empleado.nombre = empleado.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        empleado.cargo = empleado.cargo.trimmingCharacters(in: .whitespacesAndNewlines)
        empleado.usuario = empleado.usuario.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        empleado.pinAcceso = empleado.pinAcceso.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !empleado.nombre.isEmpty, !empleado.cargo.isEmpty, !empleado.usuario.isEmpty, !empleado.pinAcceso.isEmpty else {
            throw TiendaError.credencialesIncompletas
        }

        OperacionLogger.registrar(
            modulo: "Empleados",
            accion: "Modificar empleado",
            detalle: "Se actualizo el empleado \(empleado.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
