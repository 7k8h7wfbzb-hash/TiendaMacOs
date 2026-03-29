//
//  PromocionViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class PromocionViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarPromocion(_ promocion: PromocionProducto) throws {
        promocion.nombre = promocion.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        promocion.tipoPromocion = promocion.tipoPromocion.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !promocion.nombre.isEmpty,
              !promocion.tipoPromocion.isEmpty,
              promocion.valorPromocion >= 0,
              promocion.producto != nil
        else { return }

        modelContext.insert(promocion)
        OperacionLogger.registrar(
            modulo: "Promociones",
            accion: "Crear promocion",
            detalle: "Se registro la promocion \(promocion.nombre) para \(promocion.producto?.nombre ?? "Sin producto").",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarPromocion(_ promocion: PromocionProducto) throws {
        let nombre = promocion.nombre
        modelContext.delete(promocion)
        OperacionLogger.registrar(
            modulo: "Promociones",
            accion: "Eliminar promocion",
            detalle: "Se elimino la promocion \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
