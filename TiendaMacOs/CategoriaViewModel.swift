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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func guardarCategoria(nombre: String) {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombreLimpio.isEmpty else { return }
        let categoria = Categoria(nombre: nombreLimpio)
        modelContext.insert(categoria)
    }
    
    func eliminarCategoria(categoria: Categoria) {
        modelContext.delete(categoria)
    }
}
