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
    var usuario: String
    var pinAcceso: String
    @Relationship(deleteRule: .nullify) var ventas: [Venta] = []
    @Relationship(deleteRule: .nullify) var operaciones: [RegistroOperacion] = []
    @Relationship(deleteRule: .nullify) var movimientosKardex: [Kardex] = []
    
    init(nombre: String, cargo: String, usuario: String = "", pinAcceso: String = "") {
        self.nombre = nombre
        self.cargo = cargo
        self.usuario = usuario
        self.pinAcceso = pinAcceso
    }
}

@Model
class Cliente {
    var cedula: String
    var nombre: String
    var telefono: String
    var nivelFidelidad: String
    var descuentoFidelidad: Double
    var puntosAcumulados: Int
    @Relationship(deleteRule: .nullify) var compras: [Venta] = []
    
    init(
        cedula: String,
        nombre: String,
        telefono: String,
        nivelFidelidad: String = "Bronce",
        descuentoFidelidad: Double = 0,
        puntosAcumulados: Int = 0
    ) {
        self.cedula = cedula
        self.nombre = nombre
        self.telefono = telefono
        self.nivelFidelidad = nivelFidelidad
        self.descuentoFidelidad = descuentoFidelidad
        self.puntosAcumulados = puntosAcumulados
    }
}

// MARK: - 2. SISTEMA DE INVENTARIO Y PRODUCTOS
@Model
class Producto {
    var nombre: String
    var codigoProducto: String
    var marca: String
    var unidadMedida: String
    var detalleProducto: String
    @Attribute(.externalStorage) var fotoData: Data?
    var estadoFisico: String // Líquido, Gaseoso, Masa, Sólido
    var stockMinimo: Double
    
    var categoria: Categoria?
    
    // Relación con los lotes recibidos (Historial de entradas)
    @Relationship(deleteRule: .cascade) var lotes: [LoteProducto] = []
    
    // Relación con el Kárdex (Movimientos totales)
    @Relationship(deleteRule: .cascade) var movimientosKardex: [Kardex] = []
    @Relationship(deleteRule: .cascade) var promociones: [PromocionProducto] = []

    init(
        nombre: String,
        estado: String,
        stockMinimo: Double = 5.0,
        codigoProducto: String = "",
        marca: String = "",
        unidadMedida: String = "Unidad",
        detalleProducto: String = "",
        fotoData: Data? = nil
    ) {
        self.nombre = nombre
        self.codigoProducto = codigoProducto
        self.marca = marca
        self.unidadMedida = unidadMedida
        self.detalleProducto = detalleProducto
        self.fotoData = fotoData
        self.estadoFisico = estado
        self.stockMinimo = stockMinimo
    }
    
    // El stock operativo real se obtiene desde las existencias remanentes por lote.
    var stockActual: Double {
        lotes
            .filter { $0.estadoLote == "VIGENTE" || $0.estadoLote == "PROXIMO" }
            .reduce(0) { $0 + $1.unidadesDisponibles }
    }

    var lotesCaducados: Int {
        lotes.filter { $0.estadoLote == "CADUCADO" }.count
    }

    var lotesPorCaducar: Int {
        lotes.filter { $0.estadoLote == "PROXIMO" }.count
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
    var fechaCaducidad: Date?
    var fechaDevolucionProveedor: Date?
    var motivoDevolucionProveedor: String?
    
    var proveedor: Proveedor?
    var producto: Producto?
    @Relationship(deleteRule: .cascade) var consumos: [ConsumoLote] = []
    
    init(
        cajas: Double,
        unidadesXBox: Double,
        sueltas: Double,
        empaque: String,
        pCompra: Double,
        pVenta: Double,
        proveedor: Proveedor,
        fechaCaducidad: Date? = nil
    ) {
        self.idLote = UUID().uuidString
        self.fechaIngreso = Date() // Captura la hora actual del sistema
        self.cantidadCajas = cajas
        self.unidadesPorCaja = unidadesXBox
        self.unidadesSueltas = sueltas
        self.tipoEmpaque = empaque
        self.precioCompraCaja = pCompra
        self.precioVentaSugerido = pVenta
        self.fechaCaducidad = fechaCaducidad
        self.fechaDevolucionProveedor = nil
        self.motivoDevolucionProveedor = nil
        self.proveedor = proveedor
    }
    
    var totalUnidades: Double {
        return (cantidadCajas * unidadesPorCaja) + unidadesSueltas
    }
    
    var unidadesDisponibles: Double {
        guard fechaDevolucionProveedor == nil else { return 0 }
        return max(0, totalUnidades - consumos.reduce(0) { $0 + $1.cantidad })
    }

    var estadoLote: String {
        if fechaDevolucionProveedor != nil {
            return "DEVUELTO"
        }
        guard let fechaCaducidad else {
            return "VIGENTE"
        }

        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let vencimiento = calendario.startOfDay(for: fechaCaducidad)

        if vencimiento < hoy {
            return "CADUCADO"
        }

        if let dias = calendario.dateComponents([.day], from: hoy, to: vencimiento).day, dias <= 30 {
            return "PROXIMO"
        }

        return "VIGENTE"
    }

    var sePuedeDevolverAProveedor: Bool {
        fechaDevolucionProveedor == nil && consumos.isEmpty && totalUnidades > 0
    }
}

@Model
class Categoria {
    var nombre: String
    var categoriaPadre: Categoria?
    @Relationship(deleteRule: .nullify) var subcategorias: [Categoria] = []
    @Relationship(deleteRule: .nullify) var productos: [Producto] = []
    init(nombre: String, categoriaPadre: Categoria? = nil) {
        self.nombre = nombre
        self.categoriaPadre = categoriaPadre
    }

    var nombreCompleto: String {
        if let categoriaPadre {
            return "\(categoriaPadre.nombre) / \(nombre)"
        }
        return nombre
    }

    var esSubcategoria: Bool {
        categoriaPadre != nil
    }
}

@Model
class Proveedor {
    var nombre: String
    var ruc: String
    var contacto: String
    @Relationship(deleteRule: .nullify) var lotesEntregados: [LoteProducto] = []
    @Relationship(deleteRule: .nullify) var promociones: [PromocionProducto] = []
    
    init(nombre: String, ruc: String, contacto: String) {
        self.nombre = nombre
        self.ruc = ruc
        self.contacto = contacto
    }
}

@Model
class PromocionProducto {
    var nombre: String
    var tipoPromocion: String
    var valorPromocion: Double
    var fechaInicio: Date
    var fechaFin: Date
    var activa: Bool
    var combinableConFidelidad: Bool
    var producto: Producto?
    var proveedor: Proveedor?

    init(
        nombre: String,
        tipoPromocion: String,
        valorPromocion: Double,
        fechaInicio: Date,
        fechaFin: Date,
        activa: Bool = true,
        combinableConFidelidad: Bool = true,
        producto: Producto? = nil,
        proveedor: Proveedor? = nil
    ) {
        self.nombre = nombre
        self.tipoPromocion = tipoPromocion
        self.valorPromocion = valorPromocion
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.activa = activa
        self.combinableConFidelidad = combinableConFidelidad
        self.producto = producto
        self.proveedor = proveedor
    }

    func estaVigente(en fecha: Date = Date()) -> Bool {
        activa && fechaInicio <= fecha && fechaFin >= fecha
    }

    func descuentoUnitario(precioBase: Double) -> Double {
        guard estaVigente(), precioBase > 0 else { return 0 }
        switch tipoPromocion {
        case "PORCENTAJE":
            return min(precioBase, precioBase * (valorPromocion / 100))
        case "PRECIO_ESPECIAL":
            return min(precioBase, max(precioBase - valorPromocion, 0))
        case "MONTO_FIJO":
            return min(precioBase, valorPromocion)
        default:
            return 0
        }
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
    var empleado: Empleado?
    
    init(tipo: String, cantidad: Double, concepto: String, costo: Double, producto: Producto, empleado: Empleado? = nil) {
        self.tipoMovimiento = tipo
        self.cantidad = cantidad
        self.concepto = concepto
        self.costoUnitarioEnEseMomento = costo
        self.producto = producto
        self.empleado = empleado
    }
}

@Model
class Venta {
    var fecha: Date = Date()
    var numeroFactura: String
    var subtotal: Double
    var impuesto: Double
    var total: Double
    var estadoFactura: String
    var metodoPago: String?
    var fechaPago: Date?
    var motivoAnulacion: String?
    @Relationship(deleteRule: .cascade) var detalles: [DetalleVenta] = []
    
    var empleado: Empleado?
    var cliente: Cliente?
    
    init(
        numero: String,
        subtotal: Double = 0,
        impuesto: Double = 0,
        total: Double = 0,
        empleado: Empleado,
        cliente: Cliente,
        estadoFactura: String = "BORRADOR"
    ) {
        self.numeroFactura = numero
        self.subtotal = subtotal
        self.impuesto = impuesto
        self.total = total
        self.estadoFactura = estadoFactura
        self.metodoPago = nil
        self.fechaPago = nil
        self.motivoAnulacion = nil
        self.empleado = empleado
        self.cliente = cliente
    }
    
    var estaPagada: Bool {
        estadoFactura == "PAGADA"
    }
    
    var sePuedeEditar: Bool {
        estadoFactura != "PAGADA" && estadoFactura != "ANULADA"
    }
    
    func recalcularTotales(tasaImpuesto: Double = 0.15) {
        subtotal = detalles.reduce(0) { $0 + $1.subtotal }
        impuesto = subtotal * tasaImpuesto
        total = subtotal + impuesto
    }
}

@Model
class DetalleVenta {
    var cantidad: Double  // Double para permitir kg, litros, etc.
    var precioBaseSnapshot: Double
    var precioUnitarioSnapshot: Double // Precio al que se vendió en ese momento exacto
    var descuentoPromocionUnitario: Double
    var descuentoFidelidadUnitario: Double
    var promocionAplicadaNombre: String?
    var subtotal: Double {
        return cantidad * precioUnitarioSnapshot
    }
    
    // Relaciones
    var producto: Producto?
    var venta: Venta?
    @Relationship(deleteRule: .cascade) var consumos: [ConsumoLote] = []
    
    init(cantidad: Double, precio: Double, producto: Producto) {
        self.cantidad = cantidad
        self.precioBaseSnapshot = precio
        self.precioUnitarioSnapshot = precio
        self.descuentoPromocionUnitario = 0
        self.descuentoFidelidadUnitario = 0
        self.promocionAplicadaNombre = nil
        self.producto = producto
    }
}

@Model
class ConsumoLote {
    var cantidad: Double
    var lote: LoteProducto?
    var detalleVenta: DetalleVenta?
    
    init(cantidad: Double, lote: LoteProducto, detalleVenta: DetalleVenta) {
        self.cantidad = cantidad
        self.lote = lote
        self.detalleVenta = detalleVenta
    }
}

@Model
class RegistroOperacion {
    var fecha: Date
    var modulo: String
    var accion: String
    var detalle: String
    var empleado: Empleado?
    
    init(modulo: String, accion: String, detalle: String, empleado: Empleado?) {
        self.fecha = Date()
        self.modulo = modulo
        self.accion = accion
        self.detalle = detalle
        self.empleado = empleado
    }
}
