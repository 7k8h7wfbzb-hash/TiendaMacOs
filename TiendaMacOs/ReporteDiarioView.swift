//
//  ReporteDiarioView.swift
//  TiendaMacOs
//

import Charts
import SwiftData
import SwiftUI

private struct ReporteDiarioChartPoint: Identifiable {
    let id = UUID()
    let categoria: String
    let valor: Double
    let color: Color
}

struct ReporteDiarioView: View {
    @Query(sort: \Venta.fecha, order: .reverse) private var ventas: [Venta]
    @Query(sort: \Kardex.fecha, order: .reverse) private var movimientos: [Kardex]

    private var inicioDelDia: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var ventasHoy: [Venta] {
        ventas.filter { $0.fecha >= inicioDelDia }
    }

    private var movimientosHoy: [Kardex] {
        movimientos.filter { $0.fecha >= inicioDelDia }
    }

    private var cobradasHoy: Double {
        ventasHoy.filter { $0.estadoFactura == "PAGADA" }.reduce(0) { $0 + $1.total }
    }

    private var emitidasHoy: Double {
        ventasHoy.filter { $0.estadoFactura == "EMITIDA" }.reduce(0) { $0 + $1.total }
    }

    private var entradasHoy: Double {
        movimientosHoy.filter { $0.tipoMovimiento == "ENTRADA" }.reduce(0) { $0 + $1.cantidad }
    }

    private var salidasHoy: Double {
        movimientosHoy.filter { $0.tipoMovimiento == "SALIDA" }.reduce(0) { $0 + $1.cantidad }
    }

    private var resumenChartPoints: [ReporteDiarioChartPoint] {
        [
            ReporteDiarioChartPoint(categoria: "Cobrado", valor: cobradasHoy, color: .green),
            ReporteDiarioChartPoint(categoria: "Por cobrar", valor: emitidasHoy, color: .orange),
            ReporteDiarioChartPoint(categoria: "Entradas", valor: entradasHoy, color: .teal),
            ReporteDiarioChartPoint(categoria: "Salidas", valor: salidasHoy, color: .red)
        ]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                encabezado
                resumenGrid
                graficoResumen
                movimientosRecientes
            }
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 580)
        .tiendaWindowBackground()
    }

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("Reporte Diario", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Cierre visual del dia con ventas, cobros y movimientos de inventario.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Date(), format: .dateTime.day().month().year())
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var resumenGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            resumenCard("Facturas Hoy", "\(ventasHoy.count)", color: .blue)
            resumenCard("Cobrado Hoy", "$\(String(format: "%.2f", cobradasHoy))", color: .green)
            resumenCard("Por Cobrar Hoy", "$\(String(format: "%.2f", emitidasHoy))", color: .orange)
            resumenCard("Entradas", "\(String(format: "%.0f", entradasHoy)) und", color: .teal)
            resumenCard("Salidas", "\(String(format: "%.0f", salidasHoy)) und", color: .red)
        }
    }

    private var movimientosRecientes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actividad reciente")
                .font(.headline)

            List {
                ForEach(movimientos.prefix(10), id: \.persistentModelID) { movimiento in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movimiento.producto?.nombre ?? "Sin producto")
                                .font(.headline)
                            Text(movimiento.concepto)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let empleado = movimiento.empleado {
                                Text("Responsable: \(empleado.nombre)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(movimiento.tipoMovimiento)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(movimiento.tipoMovimiento == "ENTRADA" ? .green : .red)
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
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var graficoResumen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen operativo de hoy")
                .font(.headline)

            Chart(resumenChartPoints) { punto in
                BarMark(
                    x: .value("Categoria", punto.categoria),
                    y: .value("Valor", punto.valor)
                )
                .foregroundStyle(punto.color)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(String(format: "%.0f", punto.valor))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 220)
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func resumenCard(_ titulo: String, _ valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 20)
    }
}

#Preview {
    ReporteDiarioView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
