//
//  DashboardView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @State private var seleccion: SeccionDashboard? = .categorias
    @State private var mensajeError = ""
    @State private var mostrarError = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        } detail: {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
            .padding(18)
        }
        .tiendaWindowBackground()
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                        .padding(.top, 18)

                    VStack(spacing: 10) {
                        ForEach(SeccionDashboard.allCases) { seccion in
                            Button {
                                seleccion = seccion
                            } label: {
                                sidebarRow(for: seccion)
                            }
                            .buttonStyle(.plain)
                            .applyDashboardShortcut(for: seccion)
                            .help(seccion.descripcionAyuda)
                        }
                    }
                    .padding(.horizontal, 12)

                    globalShortcutsCard
                        .padding(.horizontal, 12)
                }
                .padding(.bottom, 12)
            }

            Spacer()
            
            Button {
                do {
                    try employeeSession.cerrarSesion(modelContext: modelContext)
                } catch {
                    mensajeError = error.localizedDescription
                    mostrarError = true
                }
            } label: {
                Label("Cerrar sesion", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 18)
                    .tiendaSurfaceHighlight(cornerRadius: 18)
            }
            .buttonStyle(.plain)
            .help("Cerrar la sesion actual")
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tienda")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Panel principal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.cyan)
            }
            
            if let empleado = employeeSession.empleadoActual {
                VStack(alignment: .leading, spacing: 10) {
                    Text(empleado.nombre)
                        .font(.headline)
                    Text(empleado.cargo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        quickPill(texto: empleado.usuario)
                        quickPill(texto: "Sesion activa")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .tiendaGlassCard(cornerRadius: 28)
        .tiendaSurfaceHighlight(cornerRadius: 28)
        .padding(.horizontal, 12)
    }

    private var globalShortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atajos Globales")
                .font(.headline)
            shortcutHint("⌘1...⌘9", texto: "Cambiar de panel")
            shortcutHint("⌘N", texto: "Ir al formulario")
            shortcutHint("Enter", texto: "Guardar o avanzar")
            shortcutHint("Delete", texto: "Eliminar seleccionado")
            shortcutHint("Esc", texto: "Cerrar dialogos")
        }
        .padding(16)
        .tiendaGlassCard(cornerRadius: 24)
        .tiendaSurfaceHighlight(cornerRadius: 24)
    }
    
    private func quickPill(texto: String) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }

    private func shortcutHint(_ atajo: String, texto: String) -> some View {
        HStack(spacing: 10) {
            Text(atajo)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
            Text(texto)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func sidebarRow(for seccion: SeccionDashboard) -> some View {
        HStack(spacing: 12) {
            Image(systemName: seccion.icono)
                .frame(width: 20)
                .foregroundStyle(seccion.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(seccion.titulo)
                    .font(.headline)
                    .foregroundStyle(seleccion == seccion ? Color.primary : seccion.color)
                Text(seccion.subtitulo)
                    .font(.caption)
                    .foregroundStyle(seleccion == seccion ? seccion.color.opacity(0.9) : .secondary)
            }
            Spacer()
            if let atajoTexto = seccion.atajoTexto {
                Text(atajoTexto)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(seleccion == seccion ? seccion.color : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: seleccion == seccion ? [seccion.color.opacity(0.22), seccion.color.opacity(0.08)] : [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .tiendaSecondaryGlass(cornerRadius: 18)
        .tiendaSurfaceHighlight(cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch seleccion ?? .categorias {
        case .categorias:
            CategoriaView()
        case .proveedores:
            VistaProveedor()
        case .clientes:
            ClienteView()
        case .empleados:
            EmpleadoView()
        case .productos:
            ProductoView()
        case .promociones:
            PromocionView()
        case .lotes:
            LoteProductoView()
        case .ventas:
            VentaView()
        case .kardex:
            KardexView()
        case .cuentasPorCobrar:
            CuentasPorCobrarView()
        case .reportes:
            ReporteDiarioView()
        case .bitacora:
            BitacoraView()
        }
    }
}

private enum SeccionDashboard: String, CaseIterable, Identifiable {
    case categorias
    case proveedores
    case clientes
    case empleados
    case productos
    case promociones
    case lotes
    case ventas
    case kardex
    case cuentasPorCobrar
    case reportes
    case bitacora

    var id: String { rawValue }

    var atajoTexto: String? {
        switch self {
        case .categorias:
            return "⌘1"
        case .proveedores:
            return "⌘2"
        case .clientes:
            return "⌘3"
        case .empleados:
            return "⌘4"
        case .productos:
            return "⌘5"
        case .promociones:
            return nil
        case .lotes:
            return "⌘6"
        case .ventas:
            return "⌘7"
        case .kardex:
            return "⌘8"
        case .bitacora:
            return "⌘9"
        case .cuentasPorCobrar, .reportes:
            return nil
        }
    }

    var titulo: String {
        switch self {
        case .categorias:
            return "Categorias"
        case .proveedores:
            return "Proveedores"
        case .clientes:
            return "Clientes"
        case .empleados:
            return "Empleados"
        case .productos:
            return "Productos"
        case .promociones:
            return "Promociones"
        case .lotes:
            return "Lotes"
        case .ventas:
            return "Ventas"
        case .kardex:
            return "Kardex"
        case .cuentasPorCobrar:
            return "Cuentas por Cobrar"
        case .reportes:
            return "Reporte Diario"
        case .bitacora:
            return "Bitacora"
        }
    }

    var subtitulo: String {
        switch self {
        case .categorias:
            return "Organiza los grupos"
        case .proveedores:
            return "Gestiona tus contactos"
        case .clientes:
            return "Administra tus ventas"
        case .empleados:
            return "Organiza tu equipo"
        case .productos:
            return "Controla inventario"
        case .promociones:
            return "Ofertas y descuentos"
        case .lotes:
            return "Registra entradas"
        case .ventas:
            return "Gestiona facturas"
        case .kardex:
            return "Sigue movimientos"
        case .cuentasPorCobrar:
            return "Controla pendientes"
        case .reportes:
            return "Cierre del dia"
        case .bitacora:
            return "Audita operaciones"
        }
    }

    var icono: String {
        switch self {
        case .categorias:
            return "square.grid.2x2.fill"
        case .proveedores:
            return "shippingbox.fill"
        case .clientes:
            return "person.2.fill"
        case .empleados:
            return "person.crop.rectangle.stack.fill"
        case .productos:
            return "cube.box.fill"
        case .promociones:
            return "tag.badge.plus"
        case .lotes:
            return "shippingbox.and.arrow.backward.fill"
        case .ventas:
            return "cart.fill.badge.plus"
        case .kardex:
            return "arrow.left.arrow.right.circle.fill"
        case .cuentasPorCobrar:
            return "creditcard.and.123"
        case .reportes:
            return "chart.bar.xaxis"
        case .bitacora:
            return "list.clipboard.fill"
        }
    }

    var descripcionAyuda: String {
        if let atajoTexto {
            return "Abrir \(titulo). Atajo: \(atajoTexto)"
        }
        return "Abrir \(titulo)"
    }

    var color: Color {
        switch self {
        case .categorias:
            return .blue
        case .proveedores:
            return .teal
        case .clientes:
            return .green
        case .empleados:
            return .indigo
        case .productos:
            return .mint
        case .promociones:
            return .pink
        case .lotes:
            return .cyan
        case .ventas:
            return .orange
        case .kardex:
            return .red
        case .cuentasPorCobrar:
            return .yellow
        case .reportes:
            return .purple
        case .bitacora:
            return .brown
        }
    }
}

private extension View {
    @ViewBuilder
    func applyDashboardShortcut(for seccion: SeccionDashboard) -> some View {
        switch seccion {
        case .categorias:
            keyboardShortcut("1", modifiers: .command)
        case .proveedores:
            keyboardShortcut("2", modifiers: .command)
        case .clientes:
            keyboardShortcut("3", modifiers: .command)
        case .empleados:
            keyboardShortcut("4", modifiers: .command)
        case .productos:
            keyboardShortcut("5", modifiers: .command)
        case .promociones:
            self
        case .lotes:
            keyboardShortcut("6", modifiers: .command)
        case .ventas:
            keyboardShortcut("7", modifiers: .command)
        case .kardex:
            keyboardShortcut("8", modifiers: .command)
        case .bitacora:
            keyboardShortcut("9", modifiers: .command)
        case .cuentasPorCobrar, .reportes:
            self
        }
    }
}

#Preview {
    DashboardView()
        .environment(EmployeeSession())
        .modelContainer(for: [Categoria.self, Proveedor.self, Cliente.self, Empleado.self, Producto.self, LoteProducto.self, ConsumoLote.self, Venta.self, DetalleVenta.self, Kardex.self, RegistroOperacion.self], inMemory: true)
}
