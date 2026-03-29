//
//  OperacionLogger.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

enum OperacionLogger {
    static func registrar(
        modulo: String,
        accion: String,
        detalle: String,
        empleado: Empleado?,
        modelContext: ModelContext
    ) {
        let registro = RegistroOperacion(modulo: modulo, accion: accion, detalle: detalle, empleado: empleado)
        modelContext.insert(registro)
    }
}
