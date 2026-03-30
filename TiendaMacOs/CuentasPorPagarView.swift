//
//  CuentasPorPagarView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct CuentasPorPagarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \LoteProducto.fechaIngreso, order: .reverse) private var lotes: [LoteProducto]

    @State private var viewModel: ContabilidadViewModel?
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var metodoPagoSeleccionado = "Efectivo"

    private let metodosPago = ["Efectivo", "Transferencia"]

    private var lotesPendientes: [LoteProducto] {
        lotes.filter { lote in
            let referenciaPago = "PAGO-PROV-\(lote.idLote)"
            let referenciaCompra = "COMPRA-\(lote.idLote)"
            let tieneCompra = lote.producto != nil
            let tienePago = asientoExisteLocal(referencia: referenciaPago)
            let tieneCompraContable = asientoExisteLocal(referencia: referenciaCompra)
            return tieneCompra && tieneCompraContable && !tienePago
        }
    }

    private var totalPendiente: Double {
        lotesPendientes.reduce(0) { total, lote in
            let cajas = lote.cantidadCajas * lote.precioCompraCaja
            let precioUnitario = lote.unidadesPorCaja > 0 ? lote.precioCompraCaja / lote.unidadesPorCaja : lote.precioCompraCaja
            let sueltas = lote.unidadesSueltas * precioUnitario
            return total + cajas + sueltas
        }
    }

    /// Verifica si un asiento con esa referencia existe buscando en los asientos cargados
    private func asientoExisteLocal(referencia: String) -> Bool {
        let descriptor = FetchDescriptor<AsientoContable>(
            predicate: #Predicate<AsientoContable> { asiento in
                asiento.referencia == referencia
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if lotesPendientes.isEmpty {
                    estadoVacio
                } else {
                    listaPendientes
                }
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 560)
        .tiendaWindowBackground()
        .alert("Operación no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ContabilidadViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
        }
    }

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("Cuentas por Pagar", systemImage: "banknote.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Lotes de inventario con compra registrada pero sin pago al proveedor. Registra los pagos para mantener la contabilidad al día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                card(valor: "\(lotesPendientes.count)", titulo: "pendientes")
                card(valor: "$\(String(format: "%.2f", totalPendiente))", titulo: "por pagar")
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaPendientes: some View {
        List {
            ForEach(lotesPendientes, id: \.persistentModelID) { lote in
                LotePagoFilaView(
                    lote: lote,
                    metodosPago: metodosPago,
                    onPagar: { metodo in
                        do {
                            try viewModel?.registrarPagoProveedor(lote: lote, metodoPago: metodo)
                        } catch {
                            mensajeError = error.localizedDescription
                            mostrarError = true
                        }
                    }
                )
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("Sin cuentas pendientes")
                .font(.title3.weight(.bold))
            Text("Todos los lotes con registro contable de compra ya tienen su pago registrado.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func card(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }
}

// MARK: - Fila individual con estado propio

private struct LotePagoFilaView: View {
    let lote: LoteProducto
    let metodosPago: [String]
    let onPagar: (String) -> Void

    @State private var metodoPago = "Efectivo"

    private var montoTotal: Double {
        let cajas = lote.cantidadCajas * lote.precioCompraCaja
        let precioUnitario = lote.unidadesPorCaja > 0 ? lote.precioCompraCaja / lote.unidadesPorCaja : lote.precioCompraCaja
        let sueltas = lote.unidadesSueltas * precioUnitario
        return cajas + sueltas
    }

    private var diasPendientes: Int {
        Calendar.current.dateComponents([.day], from: lote.fechaIngreso, to: Date()).day ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lote \(lote.idLote)")
                    .font(.headline)
                HStack(spacing: 8) {
                    badge(lote.proveedor?.nombre ?? "Sin proveedor")
                    badge(lote.producto?.nombre ?? "Sin producto")
                    badge("\(diasPendientes) días")
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", montoTotal))")
                    .font(.headline.weight(.bold))
                Text(lote.fechaIngreso, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(.secondary)
            }

            Picker("Método", selection: $metodoPago) {
                ForEach(metodosPago, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
            .padding(.horizontal, 8).padding(.vertical, 8)
            .tiendaSecondaryGlass(cornerRadius: 14)

            Button("Registrar pago") {
                onPagar(metodoPago)
            }
            .tiendaPrimaryButton()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 20)
        .tiendaSurfaceHighlight(cornerRadius: 20)
    }

    private func badge(_ texto: String) -> some View {
        Text(texto)
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }
}

#Preview {
    CuentasPorPagarView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self, PromocionProducto.self, CuentaContable.self, AsientoContable.self, DetalleAsientoContable.self], inMemory: true)
}
