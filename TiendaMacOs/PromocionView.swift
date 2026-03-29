//
//  PromocionView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct PromocionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \PromocionProducto.fechaInicio, order: .reverse) private var promociones: [PromocionProducto]
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    @Query(sort: \Proveedor.nombre) private var proveedores: [Proveedor]

    @State private var viewModel: PromocionViewModel?
    @State private var nombre = ""
    @State private var tipoPromocion = "PORCENTAJE"
    @State private var valorPromocion = "0"
    @State private var fechaInicio = Date()
    @State private var fechaFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var combinableConFidelidad = true
    @State private var productoSeleccionado: Producto?
    @State private var proveedorSeleccionado: Proveedor?
    @State private var promocionAEliminar: PromocionProducto?
    @State private var mostrarConfirmacion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false

    private let tipos = ["PORCENTAJE", "PRECIO_ESPECIAL", "MONTO_FIJO"]

    private var valorPromocionNumero: Double {
        Double(valorPromocion.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var formularioValido: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        productoSeleccionado != nil &&
        valorPromocionNumero >= 0 &&
        fechaFin >= fechaInicio
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if promociones.isEmpty {
                    estadoVacio
                } else {
                    listaPromociones
                }
            }
        }
        .padding(20)
        .frame(minWidth: 880, minHeight: 560)
        .tiendaWindowBackground()
        .confirmationDialog("Eliminar promocion", isPresented: $mostrarConfirmacion) {
            Button("Eliminar", role: .destructive) {
                if let promocionAEliminar {
                    do {
                        try viewModel?.eliminarPromocion(promocionAEliminar)
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
        .onAppear {
            if viewModel == nil {
                viewModel = PromocionViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
            if productoSeleccionado == nil { productoSeleccionado = productos.first }
            if proveedorSeleccionado == nil { proveedorSeleccionado = proveedores.first }
        }
    }

    private var encabezado: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Promociones", systemImage: "tag.badge.plus")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Gestiona promociones de proveedor o producto y aplícalas automáticamente al vender.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    estadisticaCard(valor: "\(promociones.count)", titulo: "promociones")
                    estadisticaCard(valor: "\(promociones.filter { $0.estaVigente() }.count)", titulo: "activas")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    campo("Nombre", icono: "tag.fill", texto: $nombre, width: 180)
                    pickerTipo
                    campo("Valor", icono: "percent", texto: $valorPromocion, width: 100)
                    pickerProducto
                    pickerProveedor
                    Toggle("Combina fidelidad", isOn: $combinableConFidelidad)
                        .toggleStyle(.switch)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                    DatePicker("Inicio", selection: $fechaInicio, displayedComponents: .date)
                        .labelsHidden()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                    DatePicker("Fin", selection: $fechaFin, displayedComponents: .date)
                        .labelsHidden()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)

                    Button("Nuevo") {
                        nombre = ""
                        tipoPromocion = tipos.first ?? "PORCENTAJE"
                        valorPromocion = "0"
                        combinableConFidelidad = true
                    }
                    .tiendaSecondaryButton()

                    Button("Guardar") {
                        guardarPromocion()
                    }
                    .tiendaPrimaryButton()
                    .disabled(!formularioValido)
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaPromociones: some View {
        Table(promociones) {
            TableColumn("Promocion") { promocion in
                VStack(alignment: .leading, spacing: 2) {
                    Text(promocion.nombre).font(.headline)
                    Text(promocion.tipoPromocion).font(.caption).foregroundStyle(.secondary)
                }
            }
            TableColumn("Producto") { promocion in
                Text(promocion.producto?.nombre ?? "Sin producto")
            }
            TableColumn("Proveedor") { promocion in
                Text(promocion.proveedor?.nombre ?? "-")
            }
            TableColumn("Valor") { promocion in
                Text(valorTexto(promocion))
            }
            TableColumn("Vigencia") { promocion in
                Text("\(promocion.fechaInicio.formatted(date: .abbreviated, time: .omitted)) - \(promocion.fechaFin.formatted(date: .abbreviated, time: .omitted))")
            }
            TableColumn("Estado") { promocion in
                Text(promocion.estaVigente() ? "Vigente" : "Inactiva")
                    .foregroundStyle(promocion.estaVigente() ? .green : .secondary)
            }
            TableColumn("Combina") { promocion in
                Text(promocion.combinableConFidelidad ? "Si" : "No")
                    .foregroundStyle(promocion.combinableConFidelidad ? Color.primary : Color.orange)
            }
            TableColumn("") { promocion in
                Button {
                    promocionAEliminar = promocion
                    mostrarConfirmacion = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .width(44)
        }
        .tableStyle(.inset)
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash.fill")
                .font(.system(size: 42))
                .foregroundStyle(.pink)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("Aun no hay promociones")
                .font(.title3.weight(.bold))
            Text("Crea promociones comerciales para productos y se aplicarán automáticamente en la factura.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var pickerTipo: some View {
        Picker("Tipo", selection: $tipoPromocion) {
            ForEach(tipos, id: \.self) { tipo in
                Text(tipo).tag(tipo)
            }
        }
        .labelsHidden()
        .frame(width: 150)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private var pickerProducto: some View {
        Picker("Producto", selection: $productoSeleccionado) {
            Text("Producto").tag(nil as Producto?)
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
            Text("Proveedor").tag(nil as Proveedor?)
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

    private func campo(_ titulo: String, icono: String, texto: Binding<String>, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono).foregroundStyle(.pink)
            TextField(titulo, text: texto).textFieldStyle(.plain)
        }
        .frame(width: width)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func guardarPromocion() {
        guard let productoSeleccionado else { return }
        let promocion = PromocionProducto(
            nombre: nombre,
            tipoPromocion: tipoPromocion,
            valorPromocion: valorPromocionNumero,
            fechaInicio: fechaInicio,
            fechaFin: fechaFin,
            combinableConFidelidad: combinableConFidelidad,
            producto: productoSeleccionado,
            proveedor: proveedorSeleccionado
        )
        do {
            try viewModel?.guardarPromocion(promocion)
            nombre = ""
            tipoPromocion = tipos.first ?? "PORCENTAJE"
            valorPromocion = "0"
            combinableConFidelidad = true
            fechaInicio = Date()
            fechaFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        } catch {
            presentar(error)
        }
    }

    private func valorTexto(_ promocion: PromocionProducto) -> String {
        switch promocion.tipoPromocion {
        case "PORCENTAJE":
            return "\(String(format: "%.0f", promocion.valorPromocion))%"
        case "PRECIO_ESPECIAL":
            return "$\(String(format: "%.2f", promocion.valorPromocion))"
        default:
            return "$\(String(format: "%.2f", promocion.valorPromocion))"
        }
    }

    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

#Preview {
    PromocionView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self, PromocionProducto.self], inMemory: true)
}
