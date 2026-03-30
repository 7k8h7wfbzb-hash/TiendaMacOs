//
//  CuentasPorCobrarView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct CuentasPorCobrarView: View {
    @Query(sort: \Venta.fecha, order: .reverse) private var ventas: [Venta]

    private var pendientes: [Venta] {
        ventas.filter { $0.estadoFactura == EstadoFactura.emitida.rawValue }
    }

    private var totalPendiente: Double {
        pendientes.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if pendientes.isEmpty {
                    estadoVacio
                } else {
                    listaPendientes
                }
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 560)
        .tiendaWindowBackground()
    }

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("Cuentas por Cobrar", systemImage: "creditcard.and.123")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Facturas emitidas pendientes de cobro. Este panel te ayuda a seguir ventas aun no pagadas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                card(valor: "\(pendientes.count)", titulo: "facturas")
                card(valor: "$\(String(format: "%.2f", totalPendiente))", titulo: "por cobrar")
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaPendientes: some View {
        Table(pendientes) {
            TableColumn("Factura") { venta in
                Text(venta.numeroFactura)
                    .font(.headline)
            }
            TableColumn("Cliente") { venta in
                Text(venta.cliente?.nombre ?? "Sin cliente")
            }
            TableColumn("Empleado") { venta in
                Text(venta.empleado?.nombre ?? "Sin empleado")
            }
            TableColumn("Dias") { venta in
                Text("\(diasPendientes(desde: venta.fecha))")
            }
            TableColumn("Lineas") { venta in
                Text("\(venta.detalles.count)")
            }
            TableColumn("Subtotal") { venta in
                Text("$\(String(format: "%.2f", venta.subtotal))")
            }
            TableColumn("Total") { venta in
                Text("$\(String(format: "%.2f", venta.total))")
                    .font(.headline)
            }
            TableColumn("Fecha") { venta in
                Text(venta.fecha, format: .dateTime.day().month().year())
            }
        }
        .tableStyle(.inset)
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("No hay cuentas pendientes")
                .font(.title3.weight(.bold))
            Text("Todas las facturas emitidas ya fueron pagadas o aun estan en borrador.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func card(valor: String, titulo: String) -> some View {
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

    private func badge(_ texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }

    private func diasPendientes(desde fecha: Date) -> Int {
        Calendar.current.dateComponents([.day], from: fecha, to: Date()).day ?? 0
    }
}

#Preview {
    CuentasPorCobrarView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
