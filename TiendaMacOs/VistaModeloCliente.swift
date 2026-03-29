//
//  VistaModeloCliente.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 28/3/26.
//

import Foundation
import SwiftData

@Observable
class ClienteViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarCliente(cliente: Cliente) throws {
        cliente.cedula = cliente.cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nombre = cliente.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.telefono = cliente.telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nivelFidelidad = cliente.nivelFidelidad.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cliente.cedula.isEmpty, !cliente.nombre.isEmpty, !cliente.telefono.isEmpty else { return }

        modelContext.insert(cliente)
        OperacionLogger.registrar(
            modulo: "Clientes",
            accion: "Crear cliente",
            detalle: "Se registro el cliente \(cliente.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarCliente(cliente: Cliente) throws {
        let nombre = cliente.nombre
        modelContext.delete(cliente)
        OperacionLogger.registrar(
            modulo: "Clientes",
            accion: "Eliminar cliente",
            detalle: "Se elimino el cliente \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarCliente(cliente: Cliente) throws {
        cliente.cedula = cliente.cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nombre = cliente.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.telefono = cliente.telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nivelFidelidad = cliente.nivelFidelidad.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cliente.cedula.isEmpty, !cliente.nombre.isEmpty, !cliente.telefono.isEmpty else { return }

        OperacionLogger.registrar(
            modulo: "Clientes",
            accion: "Modificar cliente",
            detalle: "Se actualizo el cliente \(cliente.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
