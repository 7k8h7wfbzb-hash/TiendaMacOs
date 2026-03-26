//
//  ProveedorViewModel.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 26/3/26.
//

import Foundation
import SwiftData
@Observable
class ProveedorViewModel {
    private var modelContext:ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    
    
    func crearProveedor(proveedor:Proveedor) throws {
        modelContext.insert(proveedor)
        try modelContext.save()
    }
    
    func eliminarProveedor(proveedor:Proveedor) throws {
        
        modelContext.delete(proveedor)
        try modelContext.save()
    }
    
    
}
