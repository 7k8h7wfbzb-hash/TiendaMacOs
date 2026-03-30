//
//  ContabilidadViewModel.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

/// Linea de un asiento manual antes de persistir
struct LineaAsientoManual: Identifiable {
    let id = UUID()
    var codigoCuenta: String = ""
    var debito: Double = 0
    var credito: Double = 0
}

@Observable
class ContabilidadViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession

    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }

    // MARK: - CRUD Cuentas

    func crearCuenta(codigo: String, nombre: String, tipo: String) throws {
        let codigoLimpio = codigo.trimmingCharacters(in: .whitespacesAndNewlines)
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !codigoLimpio.isEmpty, !nombreLimpio.isEmpty else {
            throw TiendaError.datosIncompletos
        }

        let descriptor = FetchDescriptor<CuentaContable>(
            predicate: #Predicate<CuentaContable> { cuenta in
                cuenta.codigo == codigoLimpio
            }
        )
        guard try modelContext.fetch(descriptor).isEmpty else {
            throw TiendaError.codigoCuentaDuplicado
        }

        let cuenta = CuentaContable(codigo: codigoLimpio, nombre: nombreLimpio, tipo: tipo)
        modelContext.insert(cuenta)
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Crear cuenta",
            detalle: "Se creó la cuenta \(codigoLimpio) - \(nombreLimpio) (\(tipo)).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func modificarCuenta(_ cuenta: CuentaContable, nombre: String, tipo: String) throws {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombreLimpio.isEmpty else { throw TiendaError.datosIncompletos }

        cuenta.nombre = nombreLimpio
        cuenta.tipo = tipo
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Modificar cuenta",
            detalle: "Se actualizó la cuenta \(cuenta.codigo) - \(nombreLimpio).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func toggleActivaCuenta(_ cuenta: CuentaContable) throws {
        cuenta.activa.toggle()
        let estado = cuenta.activa ? "activada" : "desactivada"
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Cambiar estado cuenta",
            detalle: "Se \(estado) la cuenta \(cuenta.codigo) - \(cuenta.nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarCuenta(_ cuenta: CuentaContable) throws {
        guard cuenta.movimientos.isEmpty else {
            throw TiendaError.cuentaConMovimientos
        }
        let info = "\(cuenta.codigo) - \(cuenta.nombre)"
        modelContext.delete(cuenta)
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Eliminar cuenta",
            detalle: "Se eliminó la cuenta \(info).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    // MARK: - Asientos manuales

    func crearAsientoManual(concepto: String, lineas: [LineaAsientoManual]) throws {
        let conceptoLimpio = concepto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !conceptoLimpio.isEmpty, lineas.count >= 2 else {
            throw TiendaError.datosIncompletos
        }

        let totalDebito = lineas.reduce(0) { $0 + $1.debito }
        let totalCredito = lineas.reduce(0) { $0 + $1.credito }
        guard abs(totalDebito - totalCredito) < 0.01 else {
            throw TiendaError.asientoDesbalanceado
        }

        let fechaRef = ISO8601DateFormatter().string(from: Date()).prefix(16)
        let asiento = AsientoContable(
            referencia: "MANUAL-\(fechaRef)",
            concepto: conceptoLimpio,
            modulo: "Manual",
            empleado: employeeSession.empleadoActual
        )
        modelContext.insert(asiento)

        for linea in lineas where linea.debito > 0 || linea.credito > 0 {
            let codigoBuscar = linea.codigoCuenta
            let descriptor = FetchDescriptor<CuentaContable>(
                predicate: #Predicate<CuentaContable> { cuenta in
                    cuenta.codigo == codigoBuscar
                }
            )
            guard let cuenta = try modelContext.fetch(descriptor).first else {
                throw TiendaError.datosIncompletos
            }
            guard cuenta.activa else {
                throw TiendaError.cuentaInactiva
            }
            modelContext.insert(DetalleAsientoContable(
                debito: linea.debito,
                credito: linea.credito,
                cuenta: cuenta,
                asiento: asiento
            ))
        }

        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Asiento manual",
            detalle: "Se registró asiento manual: \(conceptoLimpio) por $\(String(format: "%.2f", totalDebito)).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func eliminarAsiento(_ asiento: AsientoContable) throws {
        guard asiento.esManual else {
            throw TiendaError.asientoNoEliminable
        }
        let info = asiento.concepto
        modelContext.delete(asiento)
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Eliminar asiento",
            detalle: "Se eliminó el asiento manual: \(info).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    // MARK: - Pagos a proveedor

    func registrarPagoProveedor(lote: LoteProducto, metodoPago: String) throws {
        try ContabilidadService.registrarPagoProveedor(
            lote: lote,
            metodoPago: metodoPago,
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Pago a proveedor",
            detalle: "Se registró pago del lote \(lote.idLote) a \(lote.proveedor?.nombre ?? "proveedor") por \(metodoPago).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    // MARK: - Liquidacion IVA

    func registrarLiquidacionIVA(monto: Double) throws {
        guard monto > 0 else { throw TiendaError.datosIncompletos }
        try ContabilidadService.registrarLiquidacionIVA(
            monto: monto,
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        OperacionLogger.registrar(
            modulo: "Contabilidad",
            accion: "Liquidación IVA",
            detalle: "Se liquidó IVA por $\(String(format: "%.2f", monto)).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
