//
//  DetalleVentaView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DetalleVentaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]

    let venta: Venta

    @State private var detalleViewModel: DetalleVentaViewModel?
    @State private var ventaViewModel: VentaViewModel?
    @State private var numeroFactura = ""
    @State private var clienteSeleccionado: Cliente?
    @State private var filtroProducto = ""
    @State private var cantidad = "1"
    @State private var precio = "0"
    @State private var productoSeleccionado: Producto?
    @State private var detalleAEliminar: DetalleVenta?
    @State private var mostrarConfirmacion = false
    @State private var mostrarPreview = false
    @State private var mostrarExporterPDF = false
    @State private var documentoPDF: FacturaPDFDocument?
    @State private var metodoPago = "Efectivo"
    @State private var motivoAnulacion = ""
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @FocusState private var campoEnfocado: CampoCapturaRapida?
    
    private let metodosPago = ["Efectivo", "Tarjeta", "Transferencia", "Credito"]

    private var stockDisponible: Double {
        productoSeleccionado?.stockActual ?? 0
    }

    private var cantidadSolicitada: Double {
        Double(cantidad.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var precioUnitario: Double {
        Double(precio.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var detallesOrdenados: [DetalleVenta] {
        venta.detalles.sorted {
            ($0.producto?.nombre ?? "") < ($1.producto?.nombre ?? "")
        }
    }

    private var vistaPreviaDescuento: (precioFinal: Double, descuentoPromocion: Double, descuentoFidelidad: Double, nombrePromocion: String?)? {
        guard let detalleViewModel, let productoSeleccionado else { return nil }
        return detalleViewModel.calcularPrecioFinal(
            precioBase: precioUnitario,
            producto: productoSeleccionado,
            cliente: venta.cliente
        )
    }

    private var productosFiltrados: [Producto] {
        let termino = filtroProducto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !termino.isEmpty else { return productos }
        return productos.filter { producto in
            producto.nombre.localizedCaseInsensitiveContains(termino) ||
            (producto.categoria?.nombre.localizedCaseInsensitiveContains(termino) ?? false)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if detallesOrdenados.isEmpty {
                    estadoVacio
                } else {
                    listaDetalles
                }
            }
        }
        .padding(20)
        .frame(minWidth: 920, minHeight: 620)
        .tiendaWindowBackground()
        .confirmationDialog("Eliminar detalle", isPresented: $mostrarConfirmacion) {
            Button("Eliminar", role: .destructive) {
                if let detalleAEliminar {
                    do {
                        try detalleViewModel?.eliminarDetalle(detalleAEliminar)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .sheet(isPresented: $mostrarPreview) {
            FacturaPreviewView(venta: venta)
        }
        .fileExporter(
            isPresented: $mostrarExporterPDF,
            document: documentoPDF,
            contentType: .pdf,
            defaultFilename: venta.numeroFactura
        ) { _ in
            documentoPDF = nil
        }
        .onAppear {
            if detalleViewModel == nil { detalleViewModel = DetalleVentaViewModel(modelContext: modelContext, employeeSession: employeeSession) }
            if ventaViewModel == nil { ventaViewModel = VentaViewModel(modelContext: modelContext, employeeSession: employeeSession) }
            sincronizarCabecera()
            if productoSeleccionado == nil { productoSeleccionado = productos.first }
            aplicarPrecioSugeridoSiHaceFalta()
        }
        .onChange(of: filtroProducto) {
            actualizarSeleccionDesdeFiltro()
        }
        .onChange(of: productoSeleccionado?.persistentModelID) {
            aplicarPrecioSugeridoSiHaceFalta()
        }
    }

    private var encabezado: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Factura \(venta.numeroFactura)", systemImage: "doc.text.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text(venta.sePuedeEditar ? "Factura editable. Puedes ajustar cabecera y lineas mientras no este pagada o anulada." : "Factura cerrada. Se muestra en modo consulta porque ya fue pagada o anulada.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack(spacing: 12) {
                    estadisticaCard(valor: "\(detallesOrdenados.count)", titulo: "lineas")
                    estadisticaCard(valor: "$\(String(format: "%.2f", venta.subtotal))", titulo: "subtotal")
                    estadisticaCard(valor: "$\(String(format: "%.2f", venta.impuesto))", titulo: "impuesto")
                    estadisticaCard(valor: "$\(String(format: "%.2f", venta.total))", titulo: "total")
                    estadoFacturaBadge
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    campoCabecera("Factura", icono: "number.square.fill", texto: $numeroFactura, width: 180)

                    Text(venta.empleado?.nombre ?? employeeSession.empleadoActual?.nombre ?? "Sin empleado")
                        .frame(width: 180)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)

                    Picker("Cliente", selection: $clienteSeleccionado) {
                        Text("Cliente").tag(nil as Cliente?)
                        ForEach(clientes, id: \.persistentModelID) { cliente in
                            Text(cliente.nombre).tag(Optional(cliente))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)
                    .disabled(!venta.sePuedeEditar)

                    Spacer(minLength: 0)

                    Button("Guardar cabecera") {
                        guardarCabecera()
                    }
                    .tiendaSecondaryButton()
                    .disabled(!venta.sePuedeEditar || numeroFactura.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || clienteSeleccionado == nil)
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Guardar cambios de cabecera. Atajo: Comando S")

                    Button("Emitir") {
                        do {
                            try ventaViewModel?.emitirFactura(venta)
                        } catch {
                            presentar(error)
                        }
                    }
                    .tiendaPrimaryButton()
                    .disabled(venta.estadoFactura != EstadoFactura.borrador.rawValue || venta.detalles.isEmpty || venta.total <= 0)
                    .keyboardShortcut("E", modifiers: [.command, .shift])
                    .help("Emitir esta factura. Atajo: Comando Mayusculas E")
                }

                HStack(spacing: 12) {
                    Picker("Metodo", selection: $metodoPago) {
                        ForEach(metodosPago, id: \.self) { metodo in
                            Text(metodo).tag(metodo)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)

                    Button("Marcar pagada") {
                        do {
                            try ventaViewModel?.marcarComoPagada(venta, metodoPago: metodoPago)
                        } catch {
                            presentar(error)
                        }
                    }
                    .tiendaPrimaryButton()
                    .disabled(venta.estadoFactura != EstadoFactura.emitida.rawValue || venta.total <= 0)
                    .keyboardShortcut("P", modifiers: [.command, .shift])
                    .help("Registrar el pago de esta factura. Atajo: Comando Mayusculas P")

                    campoMotivoAnulacion

                    Button("Anular") {
                        do {
                            try ventaViewModel?.anularFactura(venta, motivo: motivoAnulacion)
                        } catch {
                            presentar(error)
                        }
                    }
                    .tiendaSecondaryButton()
                    .help("Anular la factura con el motivo indicado")
                    .disabled(venta.estadoFactura == EstadoFactura.pagada.rawValue || venta.estadoFactura == EstadoFactura.anulada.rawValue || motivoAnulacion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer(minLength: 0)

                    Button("Vista previa") {
                        mostrarPreview = true
                    }
                    .tiendaSecondaryButton()
                    .help("Ver la factura antes de exportarla")

                    Button("Exportar PDF") {
                        documentoPDF = FacturaPDFExporter.makeDocument(for: venta)
                        mostrarExporterPDF = documentoPDF != nil
                    }
                    .tiendaSecondaryButton()
                    .help("Exportar la factura en PDF")

                    Button("Cerrar") {
                        dismiss()
                    }
                    .tiendaSecondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .help("Cerrar esta ventana. Atajo: Escape")
                }
            }

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Filtrar producto o categoria", text: $filtroProducto)
                        .textFieldStyle(.plain)
                        .frame(width: 240)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                        .disabled(!venta.sePuedeEditar)
                        .focused($campoEnfocado, equals: .filtro)
                        .submitLabel(.next)
                        .onSubmit {
                            actualizarSeleccionDesdeFiltro()
                            campoEnfocado = .cantidad
                        }
                        .help("Filtrar productos para encontrarlos mas rapido")

                    Picker("Producto", selection: $productoSeleccionado) {
                        Text("Producto").tag(nil as Producto?)
                        ForEach(productosFiltrados, id: \.persistentModelID) { producto in
                            Text(producto.nombre).tag(Optional(producto))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)
                    .disabled(!venta.sePuedeEditar)
                    .help("Selecciona el producto filtrado")

                    Text("Stock: \(String(format: "%.0f", stockDisponible))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stockDisponible > 0 ? Color.secondary : Color.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "number")
                            .foregroundStyle(.pink)
                        TextField("Cantidad", text: $cantidad)
                            .textFieldStyle(.plain)
                            .submitLabel(.next)
                            .onSubmit {
                                campoEnfocado = .precio
                            }
                    }
                    .frame(width: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)
                    .disabled(!venta.sePuedeEditar)
                    .focused($campoEnfocado, equals: .cantidad)
                    .help("Cantidad del producto")

                    HStack(spacing: 10) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.pink)
                        TextField("Precio", text: $precio)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit {
                                guardarDetalle()
                            }
                    }
                    .frame(width: 140)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)
                    .disabled(!venta.sePuedeEditar)
                    .focused($campoEnfocado, equals: .precio)
                    .help("Precio unitario. Enter agrega la linea")

                    if let vistaPreviaDescuento {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Final $\(String(format: "%.2f", vistaPreviaDescuento.precioFinal))")
                                .font(.caption.weight(.semibold))
                            if let nombrePromocion = vistaPreviaDescuento.nombrePromocion {
                                Text("Promo \(nombrePromocion) -$\(String(format: "%.2f", vistaPreviaDescuento.descuentoPromocion))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if vistaPreviaDescuento.descuentoFidelidad > 0 {
                                Text("Fidelidad -$\(String(format: "%.2f", vistaPreviaDescuento.descuentoFidelidad))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                    }

                    Spacer(minLength: 0)

                    Button("Agregar detalle") {
                        guardarDetalle()
                    }
                    .tiendaPrimaryButton()
                    .disabled(!venta.sePuedeEditar || productoSeleccionado == nil || cantidadSolicitada <= 0 || cantidadSolicitada > stockDisponible || precioUnitario < 0)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Agregar una linea al detalle. Atajo: Comando Enter")
                }
            }
            .onMoveCommand(perform: manejarMovimientoProducto)

            HStack(spacing: 10) {
                accesoRapidoChip("Enter", texto: "Agregar linea desde precio")
                accesoRapidoChip("↑↓", texto: "Mover producto filtrado")
                accesoRapidoChip("⌘↩", texto: "Agregar detalle manual")
                accesoRapidoChip("⌘⇧E", texto: "Emitir")
                accesoRapidoChip("⌘⇧P", texto: "Pagar")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaDetalles: some View {
        List {
            ForEach(detallesOrdenados, id: \.persistentModelID) { detalle in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(detalle.producto?.nombre ?? "Sin producto")
                            .font(.headline)
                        HStack(spacing: 10) {
                            badge(texto: "\(String(format: "%.0f", detalle.cantidad)) und")
                            badge(texto: "$\(String(format: "%.2f", detalle.precioUnitarioSnapshot)) final")
                            if detalle.descuentoPromocionUnitario > 0 {
                                badge(texto: "Promo -$\(String(format: "%.2f", detalle.descuentoPromocionUnitario))")
                            }
                            if detalle.descuentoFidelidadUnitario > 0 {
                                badge(texto: "Fidelidad -$\(String(format: "%.2f", detalle.descuentoFidelidadUnitario))")
                            }
                            badge(texto: "Subtotal $\(String(format: "%.2f", detalle.subtotal))")
                        }
                    }

                    Spacer()

                    Button {
                        detalleAEliminar = detalle
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                    .tiendaSecondaryButton()
                    .disabled(!venta.sePuedeEditar)
                    .help("Eliminar esta linea del detalle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .tiendaSecondaryGlass(cornerRadius: 20)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.pink)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("La factura no tiene lineas")
                .font(.title3.weight(.bold))
            Text(venta.sePuedeEditar ? "Agrega productos para construir el detalle y calcular subtotal, impuesto y total." : "Esta factura ya no admite cambios.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var estadoFacturaBadge: some View {
        Text(venta.estadoFactura)
            .font(.caption.weight(.semibold))
            .foregroundStyle(colorEstadoFactura)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func campoCabecera(_ titulo: String, icono: String, texto: Binding<String>, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.pink)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
        }
        .frame(width: width)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private func badge(texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }

    private func accesoRapidoChip(_ atajo: String, texto: String) -> some View {
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
    
    private var campoMotivoAnulacion: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundStyle(.pink)
            TextField("Motivo anulacion", text: $motivoAnulacion)
                .textFieldStyle(.plain)
        }
        .frame(width: 180)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }
    
    private var colorEstadoFactura: Color {
        switch venta.estadoFactura {
        case EstadoFactura.borrador.rawValue:
            return .orange
        case EstadoFactura.emitida.rawValue:
            return .blue
        case EstadoFactura.pagada.rawValue:
            return .green
        case EstadoFactura.anulada.rawValue:
            return .red
        default:
            return .secondary
        }
    }

    private func sincronizarCabecera() {
        numeroFactura = venta.numeroFactura
        clienteSeleccionado = venta.cliente
    }

    private func actualizarSeleccionDesdeFiltro() {
        guard let primerProducto = productosFiltrados.first else {
            productoSeleccionado = nil
            return
        }
        if productoSeleccionado == nil || !productosFiltrados.contains(where: { $0.persistentModelID == productoSeleccionado?.persistentModelID }) {
            productoSeleccionado = primerProducto
        }
    }

    private func aplicarPrecioSugeridoSiHaceFalta() {
        guard let productoSeleccionado else { return }
        let precioActual = precio.trimmingCharacters(in: .whitespacesAndNewlines)
        if precioActual == "0" || precioActual.isEmpty {
            let precioSugerido = productoSeleccionado.lotes
                .sorted { $0.fechaIngreso > $1.fechaIngreso }
                .first?.precioVentaSugerido ?? 0
            precio = precioSugerido > 0 ? String(format: "%.2f", precioSugerido) : "0"
        }
    }

    private func manejarMovimientoProducto(_ direction: MoveCommandDirection) {
        guard venta.sePuedeEditar else { return }
        switch direction {
        case .up:
            moverSeleccionProducto(paso: -1)
        case .down:
            moverSeleccionProducto(paso: 1)
        default:
            break
        }
    }

    private func moverSeleccionProducto(paso: Int) {
        guard !productosFiltrados.isEmpty else {
            productoSeleccionado = nil
            return
        }

        guard let productoSeleccionado,
              let indiceActual = productosFiltrados.firstIndex(where: { $0.persistentModelID == productoSeleccionado.persistentModelID }) else {
            self.productoSeleccionado = productosFiltrados.first
            aplicarPrecioSugeridoSiHaceFalta()
            return
        }

        let nuevoIndice = min(max(indiceActual + paso, 0), productosFiltrados.count - 1)
        self.productoSeleccionado = productosFiltrados[nuevoIndice]
        aplicarPrecioSugeridoSiHaceFalta()
    }

    private func guardarCabecera() {
        guard let clienteSeleccionado else { return }
        venta.numeroFactura = numeroFactura.trimmingCharacters(in: .whitespacesAndNewlines)
        venta.empleado = employeeSession.empleadoActual
        venta.cliente = clienteSeleccionado
        do {
            try ventaViewModel?.modificarVenta(venta)
            sincronizarCabecera()
        } catch {
            presentar(error)
        }
    }

    private func guardarDetalle() {
        guard let productoSeleccionado else { return }
        let detalle = DetalleVenta(
            cantidad: cantidadSolicitada,
            precio: precioUnitario,
            producto: productoSeleccionado
        )
        detalle.venta = venta
        do {
            try detalleViewModel?.guardarDetalle(detalle)
            filtroProducto = ""
            cantidad = "1"
            precio = "0"
            actualizarSeleccionDesdeFiltro()
            aplicarPrecioSugeridoSiHaceFalta()
            campoEnfocado = .filtro
        } catch {
            presentar(error)
        }
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

private enum CampoCapturaRapida: Hashable {
    case filtro
    case cantidad
    case precio
}
