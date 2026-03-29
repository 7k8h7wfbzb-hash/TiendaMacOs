//
//  KardexViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
class KardexViewModel {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func guardarMovimiento(_ movimiento: Kardex) throws {
        movimiento.tipoMovimiento = movimiento.tipoMovimiento.trimmingCharacters(in: .whitespacesAndNewlines)
        movimiento.concepto = movimiento.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !movimiento.tipoMovimiento.isEmpty,
              !movimiento.concepto.isEmpty,
              movimiento.cantidad >= 0,
              movimiento.costoUnitarioEnEseMomento >= 0
        else { return }

        modelContext.insert(movimiento)
        try modelContext.save()
    }

    func eliminarMovimiento(_ movimiento: Kardex) throws {
        modelContext.delete(movimiento)
        try modelContext.save()
    }

    func modificarMovimiento(_ movimiento: Kardex) throws {
        movimiento.tipoMovimiento = movimiento.tipoMovimiento.trimmingCharacters(in: .whitespacesAndNewlines)
        movimiento.concepto = movimiento.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !movimiento.tipoMovimiento.isEmpty,
              !movimiento.concepto.isEmpty
        else { return }
        try modelContext.save()
    }
}
