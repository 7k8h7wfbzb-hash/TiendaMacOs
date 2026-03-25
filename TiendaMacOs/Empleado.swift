//
//  Empleado.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//


import Foundation
import SwiftData

// MARK: - 1. SISTEMA DE PERSONAS
@Model
class Empleado {
    var nombre: String
    var cargo: String
    @Relationship(deleteRule: .cascade) var ventas: [Venta] = []
    
    init(nombre: String, cargo: String) {
        self.nombre = nombre
        self.cargo = cargo
    }
}

@Model
class Cliente {
    var cedula: String
    var nombre: String
    var telefono: String
    @Relationship(deleteRule: .nullify) var compras: [Venta] = []
    
    init(cedula: String, nombre: String, telefono: String) {
        self.cedula = cedula
        self.nombre = nombre
        self.telefono = telefono
    }
}

// MARK: - 2. SISTEMA DE INVENTARIO Y PRODUCTOS
@Model
class Producto {
    var nombre: String
    var estadoFisico: String // Líquido, Gaseoso, Masa, Sólido
    var stockMinimo: Double
    
    var categoria: Categoria?
    
    // Relación con los lotes recibidos (Historial de entradas)
    @Relationship(deleteRule: .cascade) var lotes: [LoteProducto] = []
    
    // Relación con el Kárdex (Movimientos totales)
    @Relationship(deleteRule: .cascade) var movimientosKardex: [Kardex] = []

    init(nombre: String, estado: String, stockMinimo: Double = 5.0) {
        self.nombre = nombre
        self.estadoFisico = estado
        self.stockMinimo = stockMinimo
    }
    
    // Utilidad para obtener el stock total sumando todos los lotes
    var stockActual: Double {
        lotes.reduce(0) { $0 + $1.totalUnidades }
    }
}

@Model
class LoteProducto {
    var idLote: String // Podría ser un código de barras o serie
    var fechaIngreso: Date // Fecha y Hora exacta de la entrega
    var cantidadCajas: Double
    var unidadesPorCaja: Double
    var unidadesSueltas: Double
    var tipoEmpaque: String // "Caja", "Paca", "Saco", "Botella"
    
    var precioCompraCaja: Double
    var precioVentaSugerido: Double
    
    var proveedor: Proveedor?
    var producto: Producto?
    
    init(cajas: Double, unidadesXBox: Double, sueltas: Double, empaque: String, pCompra: Double, pVenta: Double, proveedor: Proveedor) {
        self.idLote = UUID().uuidString
        self.fechaIngreso = Date() // Captura la hora actual del sistema
        self.cantidadCajas = cajas
        self.unidadesPorCaja = unidadesXBox
        self.unidadesSueltas = sueltas
        self.tipoEmpaque = empaque
        self.precioCompraCaja = pCompra
        self.precioVentaSugerido = pVenta
        self.proveedor = proveedor
    }
    
    var totalUnidades: Double {
        return (cantidadCajas * unidadesPorCaja) + unidadesSueltas
    }
}

@Model
class Categoria {
    var nombre: String
    @Relationship(deleteRule: .nullify) var productos: [Producto] = []
    init(nombre: String) { self.nombre = nombre }
}

@Model
class Proveedor {
    var nombre: String
    var ruc: String
    var contacto: String
    @Relationship(deleteRule: .nullify) var lotesEntregados: [LoteProducto] = []
    
    init(nombre: String, ruc: String, contacto: String) {
        self.nombre = nombre
        self.ruc = ruc
        self.contacto = contacto
    }
}

// MARK: - 3. SISTEMA DE MOVIMIENTOS Y VENTAS
@Model
class Kardex {
    var fecha: Date = Date()
    var tipoMovimiento: String // "ENTRADA" (Compra) o "SALIDA" (Venta/Merma)
    var cantidad: Double
    var concepto: String // Ej: "Entrega Lote #45 - Proveedor Juan"
    var costoUnitarioEnEseMomento: Double
    
    var producto: Producto?
    
    init(tipo: String, cantidad: Double, concepto: String, costo: Double, producto: Producto) {
        self.tipoMovimiento = tipo
        self.cantidad = cantidad
        self.concepto = concepto
        self.costoUnitarioEnEseMomento = costo
        self.producto = producto
    }
}

@Model
class Venta {
    var fecha: Date = Date()
    var numeroFactura: String
    var total: Double
    
    var empleado: Empleado?
    var cliente: Cliente?
    
    init(numero: String, total: Double, empleado: Empleado, cliente: Cliente) {
        self.numeroFactura = numero
        self.total = total
        self.empleado = empleado
        self.cliente = cliente
    }
}