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
        guard !nombre.isEmpty else { return }
        let categoria = Categoria(nombre: nombre)
        modelContext.insert(categoria)
    }
    
    func eliminarCategoria(categoria: Categoria) {
        modelContext.delete(categoria)
    }
}
