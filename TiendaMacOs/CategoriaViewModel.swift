//
//  CategoriaViewModel.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//

import Foundation
import SwiftData

@Observable
class CategoriaViewModel {
    private var modelContext: ModelContext
    private let employeeSession: EmployeeSession
    
    init(modelContext: ModelContext, employeeSession: EmployeeSession) {
        self.modelContext = modelContext
        self.employeeSession = employeeSession
    }
    
    func guardarCategoria(nombre: String, categoriaPadre: Categoria? = nil) throws {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombreLimpio.isEmpty else { return }
        let categoria = Categoria(nombre: nombreLimpio, categoriaPadre: categoriaPadre)
        modelContext.insert(categoria)
        OperacionLogger.registrar(
            modulo: "Categorias",
            accion: categoriaPadre == nil ? "Crear categoria" : "Crear subcategoria",
            detalle: categoriaPadre == nil
                ? "Se registro la categoria \(nombreLimpio)."
                : "Se registro la subcategoria \(nombreLimpio) en \(categoriaPadre?.nombre ?? "").",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
    
    func eliminarCategoria(categoria: Categoria) throws {
        let nombre = categoria.nombre
        modelContext.delete(categoria)
        OperacionLogger.registrar(
            modulo: "Categorias",
            accion: "Eliminar categoria",
            detalle: "Se elimino la categoria \(nombre).",
            empleado: employeeSession.empleadoActual,
            modelContext: modelContext
        )
        try modelContext.save()
    }
}
