//
//  EmployeeSession.swift
//  TiendaMacOs
//

import Foundation
import SwiftData

@Observable
final class EmployeeSession {
    var empleadoActual: Empleado?
    
    var estaAutenticado: Bool {
        empleadoActual != nil
    }
    
    func iniciarSesion(usuario: String, pin: String, modelContext: ModelContext) throws {
        let usuarioLimpio = usuario.trimmingCharacters(in: .whitespacesAndNewlines)
        let pinLimpio = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !usuarioLimpio.isEmpty, !pinLimpio.isEmpty else { throw TiendaError.credencialesIncompletas }
        
        let descriptor = FetchDescriptor<Empleado>(
            predicate: #Predicate<Empleado> { empleado in
                empleado.usuario == usuarioLimpio && empleado.pinAcceso == pinLimpio
            }
        )
        
        guard let empleado = try modelContext.fetch(descriptor).first else {
            throw TiendaError.credencialesInvalidas
        }
        
        empleadoActual = empleado
        OperacionLogger.registrar(
            modulo: "Seguridad",
            accion: "Inicio de sesion",
            detalle: "El empleado \(empleado.nombre) inicio sesion en la aplicacion.",
            empleado: empleado,
            modelContext: modelContext
        )
        try modelContext.save()
    }
    
    func registrarPrimerEmpleado(
        nombre: String,
        cargo: String,
        usuario: String,
        pin: String,
        modelContext: ModelContext
    ) throws {
        let empleado = try crearEmpleadoConAcceso(
            nombre: nombre,
            cargo: cargo,
            usuario: usuario,
            pin: pin,
            modelContext: modelContext
        )
        
        empleadoActual = empleado
        OperacionLogger.registrar(
            modulo: "Seguridad",
            accion: "Primer acceso",
            detalle: "Se registro el primer empleado administrador \(empleado.nombre).",
            empleado: empleado,
            modelContext: modelContext
        )
        try modelContext.save()
    }
    
    func registrarEmpleado(
        nombre: String,
        cargo: String,
        usuario: String,
        pin: String,
        modelContext: ModelContext
    ) throws {
        let empleado = try crearEmpleadoConAcceso(
            nombre: nombre,
            cargo: cargo,
            usuario: usuario,
            pin: pin,
            modelContext: modelContext
        )
        
        empleadoActual = empleado
        OperacionLogger.registrar(
            modulo: "Seguridad",
            accion: "Registro de acceso",
            detalle: "Se registro el empleado \(empleado.nombre) desde la pantalla de acceso.",
            empleado: empleado,
            modelContext: modelContext
        )
        try modelContext.save()
    }
    
    private func crearEmpleadoConAcceso(
        nombre: String,
        cargo: String,
        usuario: String,
        pin: String,
        modelContext: ModelContext
    ) throws -> Empleado {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let cargoLimpio = cargo.trimmingCharacters(in: .whitespacesAndNewlines)
        let usuarioLimpio = usuario.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pinLimpio = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !nombreLimpio.isEmpty, !cargoLimpio.isEmpty, !usuarioLimpio.isEmpty, !pinLimpio.isEmpty else {
            throw TiendaError.credencialesIncompletas
        }
        
        let duplicado = FetchDescriptor<Empleado>(
            predicate: #Predicate<Empleado> { empleado in
                empleado.usuario == usuarioLimpio
            }
        )
        if try !modelContext.fetch(duplicado).isEmpty {
            throw TiendaError.usuarioDuplicado
        }
        
        let empleado = Empleado(nombre: nombreLimpio, cargo: cargoLimpio, usuario: usuarioLimpio, pinAcceso: pinLimpio)
        modelContext.insert(empleado)
        return empleado
    }
    
    func cerrarSesion(modelContext: ModelContext) throws {
        guard let empleadoActual else { return }
        OperacionLogger.registrar(
            modulo: "Seguridad",
            accion: "Cierre de sesion",
            detalle: "El empleado \(empleadoActual.nombre) cerro sesion.",
            empleado: empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
        self.empleadoActual = nil
    }
}
