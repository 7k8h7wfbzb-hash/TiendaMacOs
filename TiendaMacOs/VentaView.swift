//
//  VentaView.swift
//  TiendaMacOs
//

import Charts
import SwiftData
import SwiftUI

private struct VentaChartPoint: Identifiable {
    let id = UUID()
    let fecha: Date
    let total: Double
}

private struct VentaEstadoPoint: Identifiable {
    let id = UUID()
    let estado: String
    let cantidad: Int
}

struct VentaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Venta.fecha, order: .reverse) private var ventas: [Venta]
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]

    @State private var viewModel: VentaViewModel?
    @State private var siguienteFactura = ""
    @State private var clienteSeleccionado: Cliente?
    @State private var ventaAEliminar: Venta?
    @State private var ventaActiva: Venta?
    @State private var mostrarConfirmacion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var categoriaFiltroPadre: Categoria?
    @State private var subcategoriaFiltro: Categoria?
    
    private let metodosPago = ["Efectivo", "Tarjeta", "Transferencia", "Credito"]

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

    private var ventasFiltradas: [Venta] {
        ventas.filter { venta in
            guard let categoriaFiltroPadre else { return true }
            let categoriasVenta = venta.detalles.compactMap(\.producto?.categoria)
            if let subcategoriaFiltro {
                return categoriasVenta.contains { $0.persistentModelID == subcategoriaFiltro.persistentModelID }
            }
            if categoriaFiltroPadre.subcategorias.isEmpty {
                return categoriasVenta.contains { $0.persistentModelID == categoriaFiltroPadre.persistentModelID }
            }
            return categoriasVenta.contains { $0.categoriaPadre?.persistentModelID == categoriaFiltroPadre.persistentModelID }
        }
    }
    
    private var totalFacturado: Double {
        ventasFiltradas.reduce(0) { $0 + $1.total }
    }
    
    private var ventasPendientes: Int {
        ventasFiltradas.filter { $0.estadoFactura == EstadoFactura.emitida.rawValue }.count
    }
    
    private var ventasPagadas: Int {
        ventasFiltradas.filter { $0.estadoFactura == EstadoFactura.pagada.rawValue }.count
    }

    private var ventasUltimosSieteDias: [VentaChartPoint] {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())

        return (0..<7).map { desplazamiento in
            let fecha = calendario.date(byAdding: .day, value: -6 + desplazamiento, to: hoy) ?? hoy
            let siguiente = calendario.date(byAdding: .day, value: 1, to: fecha) ?? fecha
            let total = ventasFiltradas
                .filter { $0.fecha >= fecha && $0.fecha < siguiente }
                .reduce(0) { $0 + $1.total }
            return VentaChartPoint(fecha: fecha, total: total)
        }
    }

    private var ventasPorEstado: [VentaEstadoPoint] {
        let estados = EstadoFactura.allCases
        return estados.map { estado in
            VentaEstadoPoint(
                estado: estado.rawValue,
                cantidad: ventasFiltradas.filter { $0.estadoFactura == estado.rawValue }.count
            )
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if ventas.isEmpty { estadoVacio } else { listaVentas }
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 540)
        .tiendaWindowBackground()
        .confirmationDialog("Eliminar venta", isPresented: $mostrarConfirmacion) {
            Button("Eliminar", role: .destructive) {
                if let ventaAEliminar {
                    do {
                        try viewModel?.eliminarVenta(ventaAEliminar)
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
        .sheet(isPresented: Binding(
            get: { ventaActiva != nil },
            set: { if !$0 { ventaActiva = nil } }
        )) {
            if let ventaActiva {
                DetalleVentaView(venta: ventaActiva)
            }
        }
        .onChange(of: ventas.count) {
            refrescarSiguienteFactura()
        }
        .onAppear {
            if viewModel == nil { viewModel = VentaViewModel(modelContext: modelContext, employeeSession: employeeSession) }
            if clienteSeleccionado == nil { clienteSeleccionado = clientes.first }
            refrescarSiguienteFactura()
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
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ventas", systemImage: "cart.fill.badge.plus")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Registra ventas con factura, cliente y empleado responsable. El total se actualiza automaticamente desde los detalles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    estadisticaCard(valor: "\(ventasFiltradas.count)", titulo: "ventas")
                    estadisticaCard(valor: "\(ventasPendientes)", titulo: "emitidas")
                    estadisticaCard(valor: "$\(String(format: "%.0f", totalFacturado))", titulo: "facturado")
                }
            }
            HStack(spacing: 12) {
                heroPanel(
                    titulo: "Ritmo comercial",
                    detalle: "\(ventasPagadas) facturas pagadas y \(ventasPendientes) pendientes de cobro.",
                    color: .orange
                )
                heroPanel(
                    titulo: "Control operativo",
                    detalle: "Cada factura mantiene borrador, emision y pago en un flujo claro.",
                    color: .cyan
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
            HStack(spacing: 12) {
                graficoVentas
                graficoEstados
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Text(siguienteFactura.isEmpty ? "Generando factura..." : siguienteFactura)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                    Text(employeeSession.empleadoActual?.nombre ?? "Sin sesion")
                    .frame(width: 180)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)
                    Picker("Cliente", selection: $clienteSeleccionado) {
                        Text("Selecciona cliente").tag(nil as Cliente?)
                        ForEach(clientes, id: \.persistentModelID) { cliente in
                            Text(cliente.nombre).tag(Optional(cliente))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .tiendaSecondaryGlass(cornerRadius: 16)

                    Text("La factura nace en BORRADOR y luego pasa a EMITIDA o PAGADA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)

                    Button("Agregar") { guardarVenta() }
                        .tiendaPrimaryButton()
                        .disabled(employeeSession.empleadoActual == nil || clienteSeleccionado == nil || siguienteFactura.isEmpty)
                        .keyboardShortcut("N", modifiers: [.command, .shift])
                        .help("Crear una factura nueva. Atajo: Comando Mayusculas N")
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var graficoVentas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Facturacion ultimos 7 dias")
                .font(.headline)

            Chart(ventasUltimosSieteDias) { punto in
                LineMark(
                    x: .value("Fecha", punto.fecha, unit: .day),
                    y: .value("Total", punto.total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.orange)

                AreaMark(
                    x: .value("Fecha", punto.fecha, unit: .day),
                    y: .value("Total", punto.total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.orange.opacity(0.18))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
        }
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private var graficoEstados: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estado de facturas")
                .font(.headline)

            Chart(ventasPorEstado) { punto in
                BarMark(
                    x: .value("Estado", punto.estado),
                    y: .value("Cantidad", punto.cantidad)
                )
                .foregroundStyle(colorEstado(punto.estado))
                .cornerRadius(6)
            }
            .frame(width: 260, height: 190)
        }
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private func colorEstado(_ estado: String) -> Color {
        switch estado {
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

    private var listaVentas: some View {
        List {
            ForEach(ventasFiltradas, id: \.persistentModelID) { venta in
                VentaFilaView(
                    venta: venta,
                    viewModel: viewModel,
                    metodosPago: metodosPago,
                    onAbrir: { ventaActiva = venta },
                    onEliminar: {
                        ventaAEliminar = venta
                        mostrarConfirmacion = true
                    },
                    onError: { presentar($0) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.inset(alternatesRowBackgrounds: false))
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
        .help("Filtrar ventas por categoria principal")
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

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("Aun no hay ventas")
                .font(.title3.weight(.bold))
            Text("Registra la primera venta para comenzar el historial comercial.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
        .tiendaSurfaceHighlight(cornerRadius: 18)
    }
    
    private func heroPanel(titulo: String, detalle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(color.opacity(0.18))
                .overlay(Image(systemName: "waveform.path.ecg").foregroundStyle(color))
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

    private func guardarVenta() {
        guard let clienteSeleccionado else { return }
        do {
            if let venta = try viewModel?.crearVenta(cliente: clienteSeleccionado) {
                ventaActiva = venta
                refrescarSiguienteFactura()
            }
        } catch {
            presentar(error)
        }
    }
    
    private func refrescarSiguienteFactura() {
        siguienteFactura = (try? viewModel?.siguienteNumeroFactura()) ?? ""
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

// MARK: - Fila individual con estado propio

private struct VentaFilaView: View {
    let venta: Venta
    let viewModel: VentaViewModel?
    let metodosPago: [String]
    let onAbrir: () -> Void
    let onEliminar: () -> Void
    let onError: (Error) -> Void

    @State private var metodoPago = "Efectivo"
    @State private var motivoAnulacion = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(venta.numeroFactura).font(.headline)
                HStack(spacing: 10) {
                    badge(texto: venta.cliente?.nombre ?? "Sin cliente")
                    badge(texto: venta.empleado?.nombre ?? "Sin empleado")
                    badge(texto: "\(venta.detalles.count) detalles")
                    badge(texto: venta.estadoFactura)
                    if let metodo = venta.metodoPago, !metodo.isEmpty {
                        badge(texto: metodo)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(venta.fecha, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Sub $\(String(format: "%.2f", venta.subtotal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Imp $\(String(format: "%.2f", venta.impuesto))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("$\(String(format: "%.2f", venta.total))")
                    .font(.caption.weight(.semibold))
                if let fechaPago = venta.fechaPago {
                    Text(fechaPago, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Abrir") { onAbrir() }
                .tiendaSecondaryButton()
                .help("Abrir la factura para editar su detalle")

            Button("Emitir") {
                do {
                    try viewModel?.emitirFactura(venta)
                } catch {
                    onError(error)
                }
            }
            .tiendaPrimaryButton()
            .disabled(venta.estadoFactura != EstadoFactura.borrador.rawValue || venta.detalles.isEmpty || venta.total <= 0)
            .help("Emitir la factura seleccionada")

            Picker("Pago", selection: $metodoPago) {
                ForEach(metodosPago, id: \.self) { metodo in
                    Text(metodo).tag(metodo)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .tiendaSecondaryGlass(cornerRadius: 14)

            Button("Pagar") {
                do {
                    try viewModel?.marcarComoPagada(venta, metodoPago: metodoPago)
                } catch {
                    onError(error)
                }
            }
            .tiendaPrimaryButton()
            .disabled(venta.estadoFactura != EstadoFactura.emitida.rawValue || venta.total <= 0)
            .help("Marcar la factura como pagada")

            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(.orange)
                TextField("Motivo anulacion", text: $motivoAnulacion)
                    .textFieldStyle(.plain)
            }
            .frame(width: 180)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .tiendaSecondaryGlass(cornerRadius: 16)

            Button("Anular") {
                do {
                    try viewModel?.anularFactura(venta, motivo: motivoAnulacion)
                    motivoAnulacion = ""
                } catch {
                    onError(error)
                }
            }
            .tiendaSecondaryButton()
            .disabled(venta.estadoFactura == EstadoFactura.pagada.rawValue || venta.estadoFactura == EstadoFactura.anulada.rawValue || motivoAnulacion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Anular la factura actual usando el motivo indicado")

            Button {
                onEliminar()
            } label: {
                Image(systemName: "trash").foregroundStyle(.red).padding(8)
            }
            .tiendaSecondaryButton()
            .disabled(!venta.sePuedeEditar)
            .help("Eliminar la factura si aun se puede editar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 20)
        .tiendaSurfaceHighlight(cornerRadius: 20)
    }

    private func badge(texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }
}

#Preview {
    VentaView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
