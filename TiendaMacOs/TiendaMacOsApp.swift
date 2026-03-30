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
    @State private var errorBaseDatos: String?

    private let sharedModelContainer: ModelContainer? = {
        let schema = Schema([
            Empleado.self, Cliente.self, Producto.self,
            LoteProducto.self, ConsumoLote.self,
            Categoria.self, Proveedor.self,
            Kardex.self, Venta.self, DetalleVenta.self,
            RegistroOperacion.self, PromocionProducto.self,
            CuentaContable.self, AsientoContable.self, DetalleAsientoContable.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Error al crear ModelContainer: \(error)")
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = sharedModelContainer {
                    Group {
                        if employeeSession.estaAutenticado {
                            DashboardView()
                        } else {
                            LoginView()
                        }
                    }
                    .environment(employeeSession)
                    .modelContainer(container)
                } else {
                    vistaErrorBaseDatos
                }
            }
        }
    }

    private var vistaErrorBaseDatos: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Error al iniciar la base de datos")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("No se pudo crear el almacenamiento de datos. Esto puede ocurrir si la base de datos se corrompió o si hubo un cambio de versión incompatible.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Text("Intenta eliminar la carpeta de datos de la aplicación y reiniciar. Si el problema persiste, reinstala la aplicación.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button("Cerrar aplicación") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 560, height: 400)
    }
}
