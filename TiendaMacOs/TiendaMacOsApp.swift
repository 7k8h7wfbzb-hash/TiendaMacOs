//
//  TiendaMacOsApp.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//

import SwiftUI
import SwiftData

@main
struct TiendaMacOsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Empleado.self,Cliente.self,Producto.self,
            LoteProducto.self,
            Categoria.self,
            Proveedor.self,
            Kardex.self,
            Venta.self,
            DetalleVenta.self,
            
            
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            
        }
        .modelContainer(sharedModelContainer)
    }
}
