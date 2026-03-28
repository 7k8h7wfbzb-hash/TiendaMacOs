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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func guardarCliente(cliente: Cliente) throws {
        cliente.cedula = cliente.cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nombre = cliente.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.telefono = cliente.telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cliente.cedula.isEmpty, !cliente.nombre.isEmpty, !cliente.telefono.isEmpty else { return }

        modelContext.insert(cliente)
        try modelContext.save()
    }

    func eliminarCliente(cliente: Cliente) throws {
        modelContext.delete(cliente)
        try modelContext.save()
    }

    func modificarCliente(cliente: Cliente) throws {
        cliente.cedula = cliente.cedula.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.nombre = cliente.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        cliente.telefono = cliente.telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cliente.cedula.isEmpty, !cliente.nombre.isEmpty, !cliente.telefono.isEmpty else { return }

        try modelContext.save()
    }
}
