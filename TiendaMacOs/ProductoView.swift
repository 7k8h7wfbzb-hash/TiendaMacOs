//
//  ProductoView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ProductoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Namespace private var glassNamespace

    @State private var viewModel: ProductoViewModel?
    @State private var nombre = ""
    @State private var codigoProducto = ""
    @State private var marca = ""
    @State private var unidadMedida = "Unidad"
    @State private var detalleProducto = ""
    @State private var estadoFisico = "Solido"
    @State private var stockMinimo = "5"
    @State private var categoriaSeleccionada: Categoria?
    @State private var categoriaFiltroPadre: Categoria?
    @State private var subcategoriaFiltro: Categoria?
    @State private var productoAEliminar: Producto?
    @State private var productoSeleccionadoID: PersistentIdentifier?
    @State private var mostrarConfirmacion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var mostrarSelectorFoto = false
    @State private var fotoProductoData: Data?
    @FocusState private var campoEnfocado: CampoFormulario?

    private let estados = ["Solido", "Liquido", "Gaseoso", "Masa"]
    private let unidades = ["Unidad", "Caja", "Botella", "Paquete", "Libra", "Kilogramo", "Litro"]

    private enum CampoFormulario {
        case nombre
        case codigo
        case stock
    }

    private var nombreLimpio: String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var codigoLimpio: String {
        codigoProducto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stockMinimoValor: Double {
        Double(stockMinimo.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var formularioValido: Bool {
        !nombreLimpio.isEmpty && stockMinimoValor >= 0
    }
    
    private var categoriasActivas: Int {
        Set(productosFiltrados.compactMap { $0.categoria?.nombreCompleto }).count
    }

    private var categoriasDisponibles: [Categoria] {
        categorias.filter { $0.subcategorias.isEmpty }
    }

    private var categoriasPadre: [Categoria] {
        categorias.filter { $0.categoriaPadre == nil }.sorted { $0.nombre < $1.nombre }
    }

    private var subcategoriasDisponiblesFiltro: [Categoria] {
        guard let categoriaFiltroPadre else { return [] }
        if categoriaFiltroPadre.subcategorias.isEmpty {
            return [categoriaFiltroPadre]
        }
        return categoriaFiltroPadre.subcategorias.sorted { $0.nombre < $1.nombre }
    }

    private var productosConFoto: Int {
        productosFiltrados.filter { $0.fotoData != nil }.count
    }

    private var productosFiltrados: [Producto] {
        productos.filter { producto in
            guard let categoriaFiltroPadre else { return true }
            let categoriaProducto = producto.categoria
            if let subcategoriaFiltro {
                return categoriaProducto?.persistentModelID == subcategoriaFiltro.persistentModelID
            }
            if categoriaFiltroPadre.subcategorias.isEmpty {
                return categoriaProducto?.persistentModelID == categoriaFiltroPadre.persistentModelID
            }
            return categoriaProducto?.categoriaPadre?.persistentModelID == categoriaFiltroPadre.persistentModelID
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if productos.isEmpty {
                    estadoVacio
                } else {
                    listaProductos
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 540)
        .tiendaWindowBackground()
        .confirmationDialog("Eliminar producto", isPresented: $mostrarConfirmacion, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let producto = productoAEliminar {
                    do {
                        try viewModel?.eliminarProducto(producto: producto)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminara \(productoAEliminar?.nombre ?? "este producto") junto con sus lotes asociados.")
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .fileImporter(isPresented: $mostrarSelectorFoto, allowedContentTypes: [.image]) { resultado in
            cargarFoto(resultado)
        }
        .onDeleteCommand(perform: eliminarProductoSeleccionado)
        .onAppear {
            if viewModel == nil {
                viewModel = ProductoViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
            if categoriaSeleccionada == nil {
                categoriaSeleccionada = categoriasDisponibles.first
            }
            campoEnfocado = .nombre
        }
        .onChange(of: categorias.count) {
            if categoriaSeleccionada == nil {
                categoriaSeleccionada = categoriasDisponibles.first
            }
        }
        .onChange(of: categoriaFiltroPadre) {
            guard let categoriaFiltroPadre else {
                subcategoriaFiltro = nil
                return
            }
            if categoriaFiltroPadre.subcategorias.isEmpty {
                subcategoriaFiltro = categoriaFiltroPadre
            } else if !subcategoriasDisponiblesFiltro.contains(where: { $0.persistentModelID == subcategoriaFiltro?.persistentModelID }) {
                subcategoriaFiltro = nil
            }
        }
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gestion de Productos", systemImage: "cube.box.fill")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Crea productos con categoria, estado fisico y stock minimo para controlar mejor el inventario.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(productosFiltrados.count)", titulo: productosFiltrados.count == 1 ? "producto" : "productos")
                            .glassEffectID("productos-total", in: glassNamespace)
                        estadisticaCard(valor: "\(productosFiltrados.filter { $0.stockActual <= $0.stockMinimo }.count)", titulo: "en alerta")
                            .glassEffectID("productos-alerta", in: glassNamespace)
                        estadisticaCard(valor: "\(categoriasActivas)", titulo: "categorias")
                        estadisticaCard(valor: "\(productosConFoto)", titulo: "con foto")
                    }
                }
                
                HStack(spacing: 12) {
                    heroPanel(
                        titulo: "Inventario visible",
                        detalle: "Combina categoria, estado fisico y alertas minimas en una sola vista.",
                        color: .indigo
                    )
                    heroPanel(
                        titulo: "Control preventivo",
                        detalle: "Los productos en alerta se destacan antes de quedarte sin stock.",
                        color: .mint
                    )
                }

                HStack(spacing: 12) {
                    pickerCategoriaFiltroPadre
                    pickerSubcategoriaFiltro
                    Button("Limpiar filtro") {
                        categoriaFiltroPadre = nil
                        subcategoriaFiltro = nil
                    }
                    .tiendaSecondaryButton()
                    .disabled(categoriaFiltroPadre == nil && subcategoriaFiltro == nil)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        campoTexto("Nombre", icono: "shippingbox.fill", texto: $nombre, foco: .nombre)
                        campoTexto("Codigo", icono: "barcode.viewfinder", texto: $codigoProducto, foco: .codigo)
                        campoLibre("Marca", icono: "tag.fill", texto: $marca, width: 170)
                    }

                    HStack(spacing: 12) {
                        pickerUnidad
                        pickerEstado
                        pickerCategoria
                        campoTexto("Stock minimo", icono: "exclamationmark.circle.fill", texto: $stockMinimo, foco: .stock)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        campoLibre("Descripcion", icono: "text.alignleft", texto: $detalleProducto, width: 300)
                        fotoButton
                        Spacer(minLength: 0)

                        Button("Nuevo") {
                            campoEnfocado = .nombre
                        }
                        .tiendaSecondaryButton()
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Enfocar el formulario de producto. Atajo: Comando N")

                        Button {
                            guardarProducto()
                        } label: {
                            Label("Agregar", systemImage: "plus")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                        }
                        .tiendaPrimaryButton()
                        .controlSize(.large)
                        .disabled(!formularioValido)
                        .keyboardShortcut(.return, modifiers: [])
                        .help("Guardar producto. Atajo: Enter")
                    }
                }

                HStack(spacing: 10) {
                    atajoChip("⌘N", texto: "Enfocar nombre")
                    atajoChip("Enter", texto: "Guardar producto")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaProductos: some View {
        GlassEffectContainer(spacing: 16) {
            Table(productosFiltrados, selection: $productoSeleccionadoID) {
                TableColumn("Producto") { producto in
                    HStack(spacing: 10) {
                        fotoMiniatura(for: producto)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(producto.nombre)
                                .font(.headline)
                            Text(producto.codigoProducto.isEmpty ? "Sin codigo" : producto.codigoProducto)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                TableColumn("Marca / Unidad") { producto in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(producto.marca.isEmpty ? "-" : producto.marca)
                        Text(producto.unidadMedida)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Categoria") { producto in
                    Text(producto.categoria?.nombreCompleto ?? "Sin categoria")
                }
                TableColumn("Estado") { producto in
                    Text(producto.estadoFisico)
                }
                TableColumn("Stock") { producto in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.0f", producto.stockActual))")
                        Text("Min \(String(format: "%.0f", producto.stockMinimo))")
                            .font(.caption)
                            .foregroundStyle(producto.stockActual <= producto.stockMinimo ? .red : .secondary)
                    }
                }
                TableColumn("Lotes") { producto in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(producto.lotes.count)")
                        Text("Cad \(producto.lotesCaducados)")
                            .font(.caption)
                            .foregroundStyle(producto.lotesCaducados > 0 ? .red : .secondary)
                    }
                }
                TableColumn("") { producto in
                    let puedeEliminarse = producto.movimientosKardex.isEmpty
                    Button {
                        productoAEliminar = producto
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(!puedeEliminarse)
                    .help(puedeEliminarse ? "Eliminar producto" : "No puedes eliminar un producto con historial de kardex")
                }
                .width(44)
            }
            .tableStyle(.inset)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 42))
                .foregroundStyle(.indigo)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("Aun no hay productos")
                .font(.title3.weight(.bold))
            Text("Agrega tu primer producto para empezar a registrar lotes e inventario.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button {
                campoEnfocado = .nombre
            } label: {
                Label("Crear producto", systemImage: "plus.circle.fill")
            }
            .tiendaPrimaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var pickerEstado: some View {
        Picker("Estado", selection: $estadoFisico) {
            ForEach(estados, id: \.self) { estado in
                Text(estado).tag(estado)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 140)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var pickerUnidad: some View {
        Picker("Unidad", selection: $unidadMedida) {
            ForEach(unidades, id: \.self) { unidad in
                Text(unidad).tag(unidad)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 140)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var pickerCategoria: some View {
        Picker("Categoria", selection: $categoriaSeleccionada) {
            Text("Sin categoria").tag(nil as Categoria?)
            ForEach(categoriasDisponibles, id: \.persistentModelID) { categoria in
                Text(categoria.nombreCompleto).tag(Optional(categoria))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 160)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .help("Solo se pueden asignar categorias finales o subcategorias sin hijos")
    }

    private var pickerCategoriaFiltroPadre: some View {
        Picker("Categoria", selection: $categoriaFiltroPadre) {
            Text("Todas las categorias").tag(nil as Categoria?)
            ForEach(categoriasPadre, id: \.persistentModelID) { categoria in
                Text(categoria.nombre).tag(Optional(categoria))
            }
        }
        .labelsHidden()
        .frame(width: 190)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .help("Filtrar productos por categoria principal")
    }

    private var pickerSubcategoriaFiltro: some View {
        Picker("Subcategoria", selection: $subcategoriaFiltro) {
            Text(categoriaFiltroPadre == nil ? "Todas las subcategorias" : "Todas").tag(nil as Categoria?)
            ForEach(subcategoriasDisponiblesFiltro, id: \.persistentModelID) { categoria in
                Text(categoria.nombreCompleto).tag(Optional(categoria))
            }
        }
        .labelsHidden()
        .frame(width: 220)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .disabled(categoriaFiltroPadre == nil)
        .help("Acota el filtro a una subcategoria especifica")
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
        .tiendaSurfaceHighlight(cornerRadius: 18)
    }

    private func campoTexto(_ titulo: String, icono: String, texto: Binding<String>, foco: CampoFormulario) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.indigo)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
                .focused($campoEnfocado, equals: foco)
                .onSubmit {
                    avanzarFormulario(desde: foco)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .tiendaSurfaceHighlight(cornerRadius: 16)
        .help("Presiona Enter para continuar")
    }

    private func campoLibre(_ titulo: String, icono: String, texto: Binding<String>, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.indigo)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: width)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .tiendaSurfaceHighlight(cornerRadius: 16)
    }

    private var fotoButton: some View {
        HStack(spacing: 10) {
            if let fotoProductoData, let imagen = NSImage(data: fotoProductoData) {
                Image(nsImage: imagen)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.indigo)
            }
            Button(fotoProductoData == nil ? "Foto" : "Cambiar foto") {
                mostrarSelectorFoto = true
            }
            .buttonStyle(.plain)
            if fotoProductoData != nil {
                Button {
                    fotoProductoData = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .tiendaSurfaceHighlight(cornerRadius: 16)
        .help("Adjuntar una foto referencial del producto")
    }

    private func fotoMiniatura(for producto: Producto) -> some View {
        Group {
            if let fotoData = producto.fotoData, let imagen = NSImage(data: fotoData) {
                Image(nsImage: imagen)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoBadge(icono: String, texto: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
            Text(texto).lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .tiendaSecondaryGlass(cornerRadius: 12)
    }
    
    private func heroPanel(titulo: String, detalle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(color.opacity(0.16))
                .overlay(Image(systemName: "shippingbox.circle.fill").foregroundStyle(color))
                .frame(width: 40, height: 40)
            Text(titulo)
                .font(.headline)
            Text(detalle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .tiendaSurfaceHighlight(cornerRadius: 22)
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

    private func avanzarFormulario(desde campo: CampoFormulario) {
        switch campo {
        case .nombre:
            campoEnfocado = .codigo
        case .codigo:
            campoEnfocado = .stock
        case .stock:
            guardarProducto()
        }
    }

    private func guardarProducto() {
        guard formularioValido else { return }
        let producto = Producto(
            nombre: nombreLimpio,
            estado: estadoFisico,
            stockMinimo: stockMinimoValor,
            codigoProducto: codigoLimpio,
            marca: marca.trimmingCharacters(in: .whitespacesAndNewlines),
            unidadMedida: unidadMedida,
            detalleProducto: detalleProducto.trimmingCharacters(in: .whitespacesAndNewlines),
            fotoData: fotoProductoData
        )
        producto.categoria = categoriaSeleccionada
        do {
            try viewModel?.guardarProducto(producto: producto)
        } catch {
            presentar(error)
        }

        nombre = ""
        codigoProducto = ""
        marca = ""
        unidadMedida = unidades.first ?? "Unidad"
        detalleProducto = ""
        fotoProductoData = nil
        estadoFisico = estados.first ?? "Solido"
        stockMinimo = "5"
        categoriaSeleccionada = categoriasDisponibles.first
        campoEnfocado = .nombre
    }

    private func cargarFoto(_ resultado: Result<URL, Error>) {
        do {
            let url = try resultado.get()
            fotoProductoData = try Data(contentsOf: url)
        } catch {
            presentar(error)
        }
    }

    private func eliminarProductoSeleccionado() {
        guard let productoSeleccionadoID,
              let producto = productos.first(where: { $0.persistentModelID == productoSeleccionadoID }) else { return }
        productoAEliminar = producto
        mostrarConfirmacion = true
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

#Preview {
    ProductoView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
