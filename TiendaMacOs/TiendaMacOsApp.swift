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
    @State private var employeeSession = EmployeeSession()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Empleado.self,Cliente.self,Producto.self,
            LoteProducto.self,
            ConsumoLote.self,
            Categoria.self,
            Proveedor.self,
            Kardex.self,
            Venta.self,
            DetalleVenta.self,
            RegistroOperacion.self,
            PromocionProducto.self,
            
            
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
            Group {
                if employeeSession.estaAutenticado {
                    DashboardView()
                } else {
                    LoginView()
                }
            }
            .environment(employeeSession)
        }
        .modelContainer(sharedModelContainer)
    }
}
