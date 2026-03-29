//
//  LoteProductoView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct LoteProductoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \LoteProducto.fechaIngreso, order: .reverse) private var lotes: [LoteProducto]
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    @Query(sort: \Proveedor.nombre) private var proveedores: [Proveedor]

    @State private var viewModel: LoteProductoViewModel?
    @State private var cantidadCajas = "0"
    @State private var unidadesPorCaja = "0"
    @State private var unidadesSueltas = "0"
    @State private var tipoEmpaque = "Caja"
    @State private var precioCompra = "0"
    @State private var precioVenta = "0"
    @State private var controlaCaducidad = true
    @State private var fechaCaducidad = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var motivoDevolucion = ""
    @State private var productoSeleccionado: Producto?
    @State private var proveedorSeleccionado: Proveedor?
    @State private var loteAEliminar: LoteProducto?
    @State private var loteADevolver: LoteProducto?
    @State private var loteSeleccionadoID: PersistentIdentifier?
    @State private var mostrarConfirmacion = false
    @State private var mostrarDialogoDevolucion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @FocusState private var capturaRapidaEnfocada: Bool

    private let empaques = ["Caja", "Paca", "Saco", "Botella", "Bolsa"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if lotes.isEmpty {
                    estadoVacio
                } else {
                    listaLotes
                }
            }
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 560)
        .tiendaWindowBackground()
        .confirmationDialog("Eliminar lote", isPresented: $mostrarConfirmacion, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let lote = loteAEliminar {
                    do {
                        try viewModel?.eliminarLote(lote)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminara este lote del inventario.")
        }
        .confirmationDialog("Devolver lote al proveedor", isPresented: $mostrarDialogoDevolucion, titleVisibility: .visible) {
            Button("Confirmar devolucion", role: .destructive) {
                confirmarDevolucionProveedor()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Motivo actual: \(motivoDevolucion.isEmpty ? "Sin motivo" : motivoDevolucion)")
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onDeleteCommand(perform: eliminarLoteSeleccionado)
        .onAppear {
            if viewModel == nil {
                viewModel = LoteProductoViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
            if productoSeleccionado == nil { productoSeleccionado = productos.first }
            if proveedorSeleccionado == nil { proveedorSeleccionado = proveedores.first }
            capturaRapidaEnfocada = true
        }
        .onChange(of: productos.count) {
            if productoSeleccionado == nil { productoSeleccionado = productos.first }
        }
        .onChange(of: proveedores.count) {
            if proveedorSeleccionado == nil { proveedorSeleccionado = proveedores.first }
        }
    }

    private var formularioValido: Bool {
        productoSeleccionado != nil &&
        proveedorSeleccionado != nil &&
        valorDouble(cantidadCajas) >= 0 &&
        valorDouble(unidadesPorCaja) >= 0 &&
        valorDouble(unidadesSueltas) >= 0 &&
        valorDouble(precioCompra) >= 0 &&
        valorDouble(precioVenta) >= 0
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Lotes de Productos", systemImage: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Registra ingresos por lote con producto, proveedor, empaque, cantidades y precios.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(lotes.count)", titulo: lotes.count == 1 ? "lote" : "lotes")
                        estadisticaCard(valor: String(format: "%.0f", lotes.reduce(0) { $0 + $1.totalUnidades }), titulo: "unidades")
                        estadisticaCard(valor: "\(lotes.filter { $0.estadoLote == "CADUCADO" }.count)", titulo: "caducados")
                    }
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        pickerProducto
                        pickerProveedor
                        pickerEmpaque
                    }

                    HStack(spacing: 12) {
                        campoNumero("Cajas", icono: "shippingbox.fill", texto: $cantidadCajas)
                        campoNumero("Unid x caja", icono: "cube.fill", texto: $unidadesPorCaja)
                        campoNumero("Sueltas", icono: "tray.full.fill", texto: $unidadesSueltas)
                        campoNumero("Compra", icono: "dollarsign.circle.fill", texto: $precioCompra)
                        campoNumero("Venta", icono: "tag.fill", texto: $precioVenta)
                    }

                    HStack(spacing: 12) {
                        toggleCaducidad
                        if controlaCaducidad {
                            dateCaducidad
                        }
                        campoMotivoDevolucion
                        Spacer(minLength: 0)

                        Button("Nuevo") {
                            capturaRapidaEnfocada = true
                        }
                        .tiendaSecondaryButton()
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Enfocar la captura de lote. Atajo: Comando N")

                        Button {
                            guardarLote()
                        } label: {
                            Label("Agregar", systemImage: "plus")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                        }
                        .tiendaPrimaryButton()
                        .controlSize(.large)
                        .disabled(!formularioValido)
                        .keyboardShortcut(.return, modifiers: [])
                        .help("Guardar lote. Atajo: Enter")
                    }
                }

                HStack(spacing: 10) {
                    atajoChip("⌘N", texto: "Enfocar captura")
                    atajoChip("Enter", texto: "Guardar lote")
                    atajoChip("Cad.", texto: "Control sanitario")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaLotes: some View {
        GlassEffectContainer(spacing: 16) {
            Table(lotes, selection: $loteSeleccionadoID) {
                TableColumn("Producto") { lote in
                    Text(lote.producto?.nombre ?? "Producto sin asignar")
                        .font(.headline)
                }
                TableColumn("Proveedor") { lote in
                    Text(lote.proveedor?.nombre ?? "Sin proveedor")
                }
                TableColumn("Empaque") { lote in
                    Text(lote.tipoEmpaque)
                }
                TableColumn("Unidades") { lote in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tot \(String(format: "%.0f", lote.totalUnidades))")
                        Text("Disp \(String(format: "%.0f", lote.unidadesDisponibles))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Precios") { lote in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("C $\(String(format: "%.2f", lote.precioCompraCaja))")
                        Text("V $\(String(format: "%.2f", lote.precioVentaSugerido))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Caducidad") { lote in
                    VStack(alignment: .leading, spacing: 2) {
                        if let fechaCaducidad = lote.fechaCaducidad {
                            Text(fechaCaducidad, format: .dateTime.day().month().year())
                        } else {
                            Text("-")
                        }
                        Text(lote.estadoLote)
                            .font(.caption)
                            .foregroundStyle(colorEstadoLote(lote.estadoLote))
                    }
                }
                TableColumn("Fecha") { lote in
                    Text(lote.fechaIngreso, format: .dateTime.day().month().year())
                }
                TableColumn("Devolucion") { lote in
                    let puedeDevolverse = lote.sePuedeDevolverAProveedor && lote.estadoLote != "DEVUELTO"
                    Button("Devolver") {
                        loteADevolver = lote
                        if motivoDevolucion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            motivoDevolucion = lote.estadoLote == "CADUCADO" ? "Producto caducado" : "Devolucion a proveedor"
                        }
                        mostrarDialogoDevolucion = true
                    }
                    .buttonStyle(.plain)
                    .disabled(!puedeDevolverse)
                    .help(puedeDevolverse ? "Registrar devolucion al proveedor" : "Este lote ya no se puede devolver")
                }
                .width(90)
                TableColumn("") { lote in
                    let puedeEliminarse = lote.consumos.isEmpty
                    Button {
                        loteAEliminar = lote
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(!puedeEliminarse)
                    .help(puedeEliminarse ? "Eliminar lote" : "No puedes eliminar un lote si parte del stock ya fue consumido")
                }
                .width(44)
            }
            .tableStyle(.inset)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.teal)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("Aun no hay lotes")
                .font(.title3.weight(.bold))
            Text("Registra el primer lote para empezar a cargar entradas de inventario.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var pickerProducto: some View {
        Picker("Producto", selection: $productoSeleccionado) {
            Text("Selecciona producto").tag(nil as Producto?)
            ForEach(productos, id: \.persistentModelID) { producto in
                Text(producto.nombre).tag(Optional(producto))
            }
        }
        .labelsHidden()
        .frame(width: 180)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var pickerProveedor: some View {
        Picker("Proveedor", selection: $proveedorSeleccionado) {
            Text("Selecciona proveedor").tag(nil as Proveedor?)
            ForEach(proveedores, id: \.persistentModelID) { proveedor in
                Text(proveedor.nombre).tag(Optional(proveedor))
            }
        }
        .labelsHidden()
        .frame(width: 180)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var pickerEmpaque: some View {
        Picker("Empaque", selection: $tipoEmpaque) {
            ForEach(empaques, id: \.self) { empaque in
                Text(empaque).tag(empaque)
            }
        }
        .labelsHidden()
        .frame(width: 130)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var toggleCaducidad: some View {
        Toggle("Caduca", isOn: $controlaCaducidad)
            .toggleStyle(.switch)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var dateCaducidad: some View {
        DatePicker(
            "Caducidad",
            selection: $fechaCaducidad,
            displayedComponents: .date
        )
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var campoMotivoDevolucion: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.teal)
            TextField("Motivo devolucion", text: $motivoDevolucion)
                .textFieldStyle(.plain)
                .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private func campoNumero(_ titulo: String, icono: String, texto: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.teal)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
                .frame(width: 80)
                .focused($capturaRapidaEnfocada)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .help("Campo rapido para captura de lote")
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

    private func colorEstadoLote(_ estado: String) -> Color {
        switch estado {
        case "CADUCADO":
            return .red
        case "PROXIMO":
            return .orange
        case "DEVUELTO":
            return .secondary
        default:
            return .green
        }
    }

    private func valorDouble(_ texto: String) -> Double {
        Double(texto.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func guardarLote() {
        guard let proveedor = proveedorSeleccionado, let producto = productoSeleccionado, formularioValido else { return }
        let lote = LoteProducto(
            cajas: valorDouble(cantidadCajas),
            unidadesXBox: valorDouble(unidadesPorCaja),
            sueltas: valorDouble(unidadesSueltas),
            empaque: tipoEmpaque,
            pCompra: valorDouble(precioCompra),
            pVenta: valorDouble(precioVenta),
            proveedor: proveedor,
            fechaCaducidad: controlaCaducidad ? fechaCaducidad : nil
        )
        lote.producto = producto
        do {
            try viewModel?.guardarLote(lote)
        } catch {
            presentar(error)
        }

        cantidadCajas = "0"
        unidadesPorCaja = "0"
        unidadesSueltas = "0"
        precioCompra = "0"
        precioVenta = "0"
        controlaCaducidad = true
        fechaCaducidad = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        motivoDevolucion = ""
        tipoEmpaque = empaques.first ?? "Caja"
        capturaRapidaEnfocada = true
    }

    private func confirmarDevolucionProveedor() {
        guard let loteADevolver else { return }
        do {
            try viewModel?.devolverLoteAProveedor(loteADevolver, motivo: motivoDevolucion)
            motivoDevolucion = ""
            self.loteADevolver = nil
        } catch {
            presentar(error)
        }
    }

    private func eliminarLoteSeleccionado() {
        guard let loteSeleccionadoID,
              let lote = lotes.first(where: { $0.persistentModelID == loteSeleccionadoID }) else { return }
        loteAEliminar = lote
        mostrarConfirmacion = true
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

#Preview {
    LoteProductoView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
