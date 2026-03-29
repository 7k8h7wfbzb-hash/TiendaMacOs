//
//  TiendaError.swift
//  TiendaMacOs
//

import Foundation

enum TiendaError: LocalizedError {
    case empleadoConVentas
    case empleadoEnSesion
    case productoConHistorial
    case loteConConsumos
    case stockInsuficiente
    case facturaDuplicada
    case facturaNoEditable
    case facturaSinDetalle
    case metodoPagoRequerido
    case motivoAnulacionRequerido
    case credencialesIncompletas
    case credencialesInvalidas
    case sesionRequerida
    case usuarioDuplicado
    case motivoDevolucionProveedorRequerido
    case loteNoDisponibleParaDevolucion

    var errorDescription: String? {
        switch self {
        case .empleadoConVentas:
            return "No puedes eliminar un empleado que ya tiene ventas registradas."
        case .empleadoEnSesion:
            return "No puedes eliminar el empleado que tiene la sesion activa."
        case .productoConHistorial:
            return "No puedes eliminar un producto con historial de kardex."
        case .loteConConsumos:
            return "No puedes eliminar un lote que ya fue consumido por una venta."
        case .stockInsuficiente:
            return "No hay stock suficiente para completar la venta."
        case .facturaDuplicada:
            return "Ya existe una factura con ese numero."
        case .facturaNoEditable:
            return "La factura ya no se puede modificar en su estado actual."
        case .facturaSinDetalle:
            return "La factura necesita al menos una linea valida para continuar."
        case .metodoPagoRequerido:
            return "Debes indicar el metodo de pago."
        case .motivoAnulacionRequerido:
            return "Debes indicar el motivo de anulacion."
        case .credencialesIncompletas:
            return "Debes indicar usuario y PIN del empleado."
        case .credencialesInvalidas:
            return "Usuario o PIN incorrectos."
        case .sesionRequerida:
            return "Debes iniciar sesion con un empleado para realizar esta operacion."
        case .usuarioDuplicado:
            return "Ya existe un empleado registrado con ese usuario."
        case .motivoDevolucionProveedorRequerido:
            return "Debes indicar el motivo de devolucion al proveedor."
        case .loteNoDisponibleParaDevolucion:
            return "Ese lote ya no se puede devolver al proveedor."
        }
    }
}
