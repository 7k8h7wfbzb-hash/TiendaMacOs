//
//  DashboardView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @State private var seleccion: SeccionDashboard? = .categorias

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .tiendaWindowBackground()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tienda")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Panel principal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            VStack(spacing: 10) {
                ForEach(SeccionDashboard.allCases) { seccion in
                    Button {
                        seleccion = seccion
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: seccion.icono)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seccion.titulo)
                                    .font(.headline)
                                Text(seccion.subtitulo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Group {
                                if seleccion == seccion {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.16))
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .tiendaSecondaryGlass(cornerRadius: 18)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch seleccion ?? .categorias {
        case .categorias:
            CategoriaView()
        case .proveedores:
            VistaProveedor()
        }
    }
}

private enum SeccionDashboard: String, CaseIterable, Identifiable {
    case categorias
    case proveedores

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .categorias:
            return "Categorias"
        case .proveedores:
            return "Proveedores"
        }
    }

    var subtitulo: String {
        switch self {
        case .categorias:
            return "Organiza los grupos"
        case .proveedores:
            return "Gestiona tus contactos"
        }
    }

    var icono: String {
        switch self {
        case .categorias:
            return "square.grid.2x2.fill"
        case .proveedores:
            return "shippingbox.fill"
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Categoria.self, Proveedor.self], inMemory: true)
}
