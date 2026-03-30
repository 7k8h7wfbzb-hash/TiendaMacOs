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
    case datosIncompletos
    case movimientoInvalido
    case asientoDesbalanceado
    case cuentaInactiva
    case cuentaConMovimientos
    case codigoCuentaDuplicado
    case asientoNoEliminable
    case permisoInsuficiente

    var errorDescription: String? {
        switch self {
        case .empleadoConVentas:
            return "No puedes eliminar un empleado que ya tiene ventas registradas."
        case .empleadoEnSesion:
            return "No puedes eliminar el empleado que tiene la sesión activa."
        case .productoConHistorial:
            return "No puedes eliminar un producto con historial de kardex."
        case .loteConConsumos:
            return "No puedes eliminar un lote que ya fue consumido por una venta."
        case .stockInsuficiente:
            return "No hay stock suficiente para completar la venta."
        case .facturaDuplicada:
            return "Ya existe una factura con ese número."
        case .facturaNoEditable:
            return "La factura ya no se puede modificar en su estado actual."
        case .facturaSinDetalle:
            return "La factura necesita al menos una línea válida para continuar."
        case .metodoPagoRequerido:
            return "Debes indicar el método de pago."
        case .motivoAnulacionRequerido:
            return "Debes indicar el motivo de anulación."
        case .credencialesIncompletas:
            return "Debes indicar usuario y PIN del empleado."
        case .credencialesInvalidas:
            return "Usuario o PIN incorrectos."
        case .sesionRequerida:
            return "Debes iniciar sesión con un empleado para realizar esta operación."
        case .usuarioDuplicado:
            return "Ya existe un empleado registrado con ese usuario."
        case .motivoDevolucionProveedorRequerido:
            return "Debes indicar el motivo de devolución al proveedor."
        case .loteNoDisponibleParaDevolucion:
            return "Ese lote ya no se puede devolver al proveedor."
        case .datosIncompletos:
            return "Faltan datos obligatorios para completar la operación."
        case .movimientoInvalido:
            return "El movimiento de inventario no tiene datos válidos."
        case .asientoDesbalanceado:
            return "El asiento contable no está balanceado. Los débitos deben ser iguales a los créditos."
        case .cuentaInactiva:
            return "La cuenta contable está inactiva y no puede recibir movimientos."
        case .cuentaConMovimientos:
            return "No puedes eliminar una cuenta contable que ya tiene movimientos registrados."
        case .codigoCuentaDuplicado:
            return "Ya existe una cuenta contable con ese código."
        case .asientoNoEliminable:
            return "Solo se pueden eliminar asientos manuales."
        case .permisoInsuficiente:
            return "No tienes permisos para realizar esta operación. Solo los administradores pueden ejecutar esta acción."
        }
    }
}
