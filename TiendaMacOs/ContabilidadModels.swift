import Foundation
import SwiftData

@Model
class CuentaContable {
    var codigo: String
    var nombre: String
    var tipo: String
    var activa: Bool
    @Relationship(deleteRule: .nullify) var movimientos: [DetalleAsientoContable] = []

    init(codigo: String, nombre: String, tipo: String, activa: Bool = true) {
        self.codigo = codigo
        self.nombre = nombre
        self.tipo = tipo
        self.activa = activa
    }

    var saldoActual: Double {
        let bruto = movimientos.reduce(0) { acumulado, movimiento in
            acumulado + movimiento.debito - movimiento.credito
        }
        switch tipo {
        case TipoCuenta.pasivo.rawValue, TipoCuenta.ingreso.rawValue, TipoCuenta.patrimonio.rawValue:
            return -bruto
        default:
            return bruto
        }
    }

    /// Calcula el saldo considerando solo movimientos hasta una fecha de corte
    func saldoAlCorte(_ fecha: Date) -> Double {
        let movimientosFiltrados = movimientos.filter { movimiento in
            guard let asiento = movimiento.asiento else { return false }
            return asiento.fecha <= fecha
        }
        let bruto = movimientosFiltrados.reduce(0) { acumulado, movimiento in
            acumulado + movimiento.debito - movimiento.credito
        }
        switch tipo {
        case TipoCuenta.pasivo.rawValue, TipoCuenta.ingreso.rawValue, TipoCuenta.patrimonio.rawValue:
            return -bruto
        default:
            return bruto
        }
    }

    /// Calcula debitos totales en un rango de fechas
    func debitosEnRango(desde: Date, hasta: Date) -> Double {
        movimientos.filter { movimiento in
            guard let asiento = movimiento.asiento else { return false }
            return asiento.fecha >= desde && asiento.fecha <= hasta
        }
        .reduce(0) { $0 + $1.debito }
    }

    /// Calcula creditos totales en un rango de fechas
    func creditosEnRango(desde: Date, hasta: Date) -> Double {
        movimientos.filter { movimiento in
            guard let asiento = movimiento.asiento else { return false }
            return asiento.fecha >= desde && asiento.fecha <= hasta
        }
        .reduce(0) { $0 + $1.credito }
    }

    /// Saldo neto en un rango (para estado de resultados)
    func saldoEnRango(desde: Date, hasta: Date) -> Double {
        let bruto = debitosEnRango(desde: desde, hasta: hasta) - creditosEnRango(desde: desde, hasta: hasta)
        switch tipo {
        case TipoCuenta.pasivo.rawValue, TipoCuenta.ingreso.rawValue, TipoCuenta.patrimonio.rawValue:
            return -bruto
        default:
            return bruto
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

    var estaBalanceado: Bool {
        abs(totalDebito - totalCredito) < 0.01
    }

    var esManual: Bool {
        modulo == "Manual"
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
