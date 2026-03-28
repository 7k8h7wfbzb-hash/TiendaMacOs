//
//  CategoriaView.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//

import SwiftData
import SwiftUI

struct CategoriaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Namespace private var glassNamespace

    @State private var nombreCategoria = ""
    @State private var viewModelo: CategoriaViewModel?
    @State private var mostrarConfirmacion = false
    @State private var categoriaElegida: Categoria?
    @FocusState private var nombreFieldEnfocado: Bool

    private var nombreCategoriaLimpio: String {
        nombreCategoria.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if categorias.isEmpty {
                    estadoVacio
                } else {
                    listaCategorias
                }
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 500)
        .confirmationDialog(
            "Eliminar categoria de forma permanente",
            isPresented: $mostrarConfirmacion,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let cat = categoriaElegida {
                    viewModelo?.eliminarCategoria(categoria: cat)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Si eliminas \(categoriaElegida?.nombre ?? "esta categoria"), se perdera su asociacion con los productos.")
        }
        .onAppear {
            if viewModelo == nil {
                viewModelo = CategoriaViewModel(modelContext: modelContext)
            }
        }
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gestion de Categorias", systemImage: "square.grid.2x2")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Organiza mejor tus productos creando grupos claros y faciles de identificar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(categorias.count)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(categorias.count == 1 ? "categoria activa" : "categorias activas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 18)
                    .glassEffectID("contador", in: glassNamespace)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.blue)
                        TextField("Nueva categoria", text: $nombreCategoria)
                            .textFieldStyle(.plain)
                            .focused($nombreFieldEnfocado)
                            .onSubmit(agregarCategoria)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 280)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                    .glassEffectID("input", in: glassNamespace)

                    Button {
                        agregarCategoria()
                    } label: {
                        Label("Agregar", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                    }
                    .tiendaPrimaryButton()
                    .controlSize(.large)
                    .disabled(nombreCategoriaLimpio.isEmpty)
                    .help("Agrega una nueva categoria")
                    .glassEffectID("agregar", in: glassNamespace)
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaCategorias: some View {
        GlassEffectContainer(spacing: 16) {
            List {
                ForEach(categorias, id: \.persistentModelID) { categoria in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "archivebox.fill")
                                .foregroundStyle(.blue)
                        }
                        .glassEffectID(categoria.persistentModelID, in: glassNamespace)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoria.nombre)
                                .font(.system(size: 14, weight: .medium))
                            Text("Categoria registrada")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)

                        Button {
                            categoriaElegida = categoria
                            mostrarConfirmacion = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                        .tiendaSecondaryButton()
                        .help("Eliminar \(categoria.nombre)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 18)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.inset(alternatesRowBackgrounds: false))
        }
        .padding(.bottom, 12)
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 42))
                .foregroundStyle(.blue)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 20)

            Text("Sin categorias")
                .font(.title3.weight(.bold))

            Text("Crea tu primera categoria para empezar a organizar los productos de la tienda.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                nombreFieldEnfocado = true
            } label: {
                Label("Crear ahora", systemImage: "plus.circle.fill")
            }
            .tiendaPrimaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func agregarCategoria() {
        let nombre = nombreCategoriaLimpio
        guard !nombre.isEmpty else { return }

        viewModelo?.guardarCategoria(nombre: nombre)
        nombreCategoria = ""
        nombreFieldEnfocado = true
    }
}

#Preview {
    CategoriaView()
        .modelContainer(for: [Categoria.self])
}
