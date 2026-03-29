import Foundation
import SwiftData

@Model
class CuentaContable {
    var codigo: String
    var nombre: String
    var tipo: String
    @Relationship(deleteRule: .nullify) var movimientos: [DetalleAsientoContable] = []

    init(codigo: String, nombre: String, tipo: String) {
        self.codigo = codigo
        self.nombre = nombre
        self.tipo = tipo
    }

    var saldoActual: Double {
        movimientos.reduce(0) { acumulado, movimiento in
            acumulado + movimiento.debito - movimiento.credito
        }
    }
}

@Model
class AsientoContable {
    var fecha: Date
    var referencia: String
    var concepto: String
    var modulo: String
    var empleado: Empleado?
    @Relationship(deleteRule: .cascade) var detalles: [DetalleAsientoContable] = []

    init(fecha: Date = Date(), referencia: String, concepto: String, modulo: String, empleado: Empleado? = nil) {
        self.fecha = fecha
        self.referencia = referencia
        self.concepto = concepto
        self.modulo = modulo
        self.empleado = empleado
    }

    var totalDebito: Double {
        detalles.reduce(0) { $0 + $1.debito }
    }

    var totalCredito: Double {
        detalles.reduce(0) { $0 + $1.credito }
    }
}

@Model
class DetalleAsientoContable {
    var debito: Double
    var credito: Double
    var cuenta: CuentaContable?
    var asiento: AsientoContable?

    init(debito: Double = 0, credito: Double = 0, cuenta: CuentaContable, asiento: AsientoContable) {
        self.debito = debito
        self.credito = credito
        self.cuenta = cuenta
        self.asiento = asiento
    }
}
