//
//  KardexViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class KardexViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    func guardarMovimiento(_ movimiento: Kardex) throws {
        movimiento.tipoMovimiento = movimiento.tipoMovimiento.trimmingCharacters(in: .whitespacesAndNewlines)
        movimiento.concepto = movimiento.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !movimiento.tipoMovimiento.isEmpty,
              !movimiento.concepto.isEmpty,
              movimiento.cantidad >= 0,
              movimiento.costoUnitarioEnEseMomento >= 0
        else { throw TiendaError.movimientoInvalido }

        modelContext.insert(movimiento)
        OperacionLogger.registrar(
            modulo: "Kardex",
            accion: "Registrar movimiento",
            detalle: "Se registro un movimiento \(movimiento.tipoMovimiento) de \(String(format: "%.0f", movimiento.cantidad)) unidades. Concepto: \(movimiento.concepto).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarMovimiento(_ movimiento: Kardex) throws {
        let concepto = movimiento.concepto
        modelContext.delete(movimiento)
        OperacionLogger.registrar(
            modulo: "Kardex",
            accion: "Eliminar movimiento",
            detalle: "Se elimino el movimiento: \(concepto).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarMovimiento(_ movimiento: Kardex) throws {
        movimiento.tipoMovimiento = movimiento.tipoMovimiento.trimmingCharacters(in: .whitespacesAndNewlines)
        movimiento.concepto = movimiento.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !movimiento.tipoMovimiento.isEmpty,
              !movimiento.concepto.isEmpty,
              movimiento.cantidad >= 0,
              movimiento.costoUnitarioEnEseMomento >= 0
        else { throw TiendaError.movimientoInvalido }

        OperacionLogger.registrar(
            modulo: "Kardex",
            accion: "Modificar movimiento",
            detalle: "Se actualizo el movimiento: \(movimiento.concepto).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
