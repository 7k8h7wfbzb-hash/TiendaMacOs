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
    private var modelConext:ModelContext
    
    init(ModelConext: ModelContext) {
        self.modelConext = ModelConext
    }
    
    func guadarCategoria(nombre:String){
        guard !nombre.isEmpty else { return }
        let categoria = Categoria(nombre: nombre)
         modelConext.insert(categoria)
    }
    
    func eliminarCategoria(categoria: Categoria){
        modelConext.delete(categoria)
    }
}
