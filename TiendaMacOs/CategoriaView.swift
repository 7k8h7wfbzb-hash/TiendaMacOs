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
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Namespace private var glassNamespace

    @State private var nombreCategoria = ""
    @State private var categoriaPadreSeleccionada: Categoria?
    @State private var viewModelo: CategoriaViewModel?
    @State private var mostrarConfirmacion = false
    @State private var categoriaElegida: Categoria?
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var categoriaSeleccionadaID: PersistentIdentifier?
    @FocusState private var nombreFieldEnfocado: Bool

    private var nombreCategoriaLimpio: String {
        nombreCategoria.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoriasPrincipales: [Categoria] {
        categorias.filter { $0.categoriaPadre == nil }
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
                    do {
                        try viewModelo?.eliminarCategoria(categoria: cat)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Si eliminas \(categoriaElegida?.nombre ?? "esta categoria"), se perdera su asociacion con los productos.")
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onDeleteCommand(perform: eliminarCategoriaSeleccionada)
        .onAppear {
            if viewModelo == nil {
                viewModelo = CategoriaViewModel(modelContext: modelContext, employeeSession: employeeSession)
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

                    Picker("Categoria padre", selection: $categoriaPadreSeleccionada) {
                        Text("Categoria principal").tag(nil as Categoria?)
                        ForEach(categoriasPrincipales, id: \.persistentModelID) { categoria in
                            Text(categoria.nombre).tag(Optional(categoria))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                    .help("Opcional: elige una categoria padre para crear una subcategoria")

                    Button("Nuevo") {
                        nombreFieldEnfocado = true
                    }
                    .tiendaSecondaryButton()
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Enfocar el campo de categoria. Atajo: Comando N")

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
                    .keyboardShortcut(.return, modifiers: [])
                    .help("Agrega una nueva categoria. Atajo: Enter")
                    .glassEffectID("agregar", in: glassNamespace)
                }

                HStack(spacing: 10) {
                    atajoChip("⌘N", texto: "Enfocar campo")
                    atajoChip("Enter", texto: "Guardar categoria o subcategoria")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaCategorias: some View {
        GlassEffectContainer(spacing: 16) {
            List(selection: $categoriaSeleccionadaID) {
                ForEach(categoriasPrincipales, id: \.persistentModelID) { categoria in
                    categoriaRow(categoria, esSubcategoria: false)

                    ForEach(categoria.subcategorias.sorted { $0.nombre < $1.nombre }, id: \.persistentModelID) { subcategoria in
                        categoriaRow(subcategoria, esSubcategoria: true)
                    }
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

        do {
            try viewModelo?.guardarCategoria(nombre: nombre, categoriaPadre: categoriaPadreSeleccionada)
            nombreCategoria = ""
            categoriaPadreSeleccionada = nil
            nombreFieldEnfocado = true
        } catch {
            presentar(error)
        }
    }

    private func eliminarCategoriaSeleccionada() {
        guard let categoriaSeleccionadaID,
              let categoria = categorias.first(where: { $0.persistentModelID == categoriaSeleccionadaID }) else { return }
        categoriaElegida = categoria
        mostrarConfirmacion = true
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
    
    private func categoriaBadge(texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .tiendaSecondaryGlass(cornerRadius: 10)
    }

    private func atajoChip(_ atajo: String, texto: String) -> some View {
        HStack(spacing: 8) {
            Text(atajo)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
            Text(texto)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .tiendaSecondaryGlass(cornerRadius: 14)
    }

    private func categoriaRow(_ categoria: Categoria, esSubcategoria: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((esSubcategoria ? Color.cyan : Color.blue).opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: esSubcategoria ? "folder.fill.badge.plus" : "archivebox.fill")
                    .foregroundStyle(esSubcategoria ? .cyan : .blue)
            }
            .glassEffectID(categoria.persistentModelID, in: glassNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(categoria.nombre)
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 8) {
                    Text(esSubcategoria ? "Subcategoria" : "Categoria principal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    categoriaBadge(texto: "\(categoria.productos.count) productos")
                    if !categoria.subcategorias.isEmpty {
                        categoriaBadge(texto: "\(categoria.subcategorias.count) subcategorias")
                    }
                }
            }

            Spacer()

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
        .padding(.leading, esSubcategoria ? 36 : 14)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
        .tiendaSurfaceHighlight(cornerRadius: 18)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    CategoriaView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
