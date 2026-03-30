//
//  ReporteDiarioView.swift
//  TiendaMacOs
//

import Charts
import SwiftData
import SwiftUI

private struct ChartPoint: Identifiable {
    let id = UUID()
    let nombre: String
    let valor: Double
    let color: Color
}

private struct TopProducto: Identifiable {
    let id = UUID()
    let nombre: String
    let cantidad: Double
    let ingresos: Double
}

struct ReporteDiarioView: View {
    @Query(sort: \Venta.fecha, order: .reverse) private var ventas: [Venta]
    @Query(sort: \Kardex.fecha, order: .reverse) private var movimientos: [Kardex]
    @Query(sort: \LoteProducto.fechaCaducidad) private var lotes: [LoteProducto]

    @State private var fechaReporte = Date()

    private var inicioDelDia: Date {
        Calendar.current.startOfDay(for: fechaReporte)
    }
    private var finDelDia: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: inicioDelDia) ?? inicioDelDia
    }

    private var ventasHoy: [Venta] {
        ventas.filter { $0.fecha >= inicioDelDia && $0.fecha < finDelDia }
    }

    private var movimientosHoy: [Kardex] {
        movimientos.filter { $0.fecha >= inicioDelDia && $0.fecha < finDelDia }
    }

    // MARK: - Metricas monetarias

    private var cobradasHoy: Double {
        ventasHoy.filter { $0.estadoFactura == EstadoFactura.pagada.rawValue }.reduce(0) { $0 + $1.total }
    }

    private var emitidasHoy: Double {
        ventasHoy.filter { $0.estadoFactura == EstadoFactura.emitida.rawValue }.reduce(0) { $0 + $1.total }
    }

    private var anuladasHoy: Int {
        ventasHoy.filter { $0.estadoFactura == EstadoFactura.anulada.rawValue }.count
    }

    /// Costo de ventas del dia (COGS) — suma de costos de lotes consumidos en ventas del dia
    private var costoVentasHoy: Double {
        ventasHoy
            .filter { $0.estadoFactura == EstadoFactura.pagada.rawValue || $0.estadoFactura == EstadoFactura.emitida.rawValue }
            .reduce(0) { total, venta in
                total + venta.detalles.reduce(0) { parcial, detalle in
                    parcial + detalle.consumos.reduce(0) { acc, consumo in
                        guard let lote = consumo.lote else { return acc }
                        let costoUnitario = lote.unidadesPorCaja > 0 ? lote.precioCompraCaja / lote.unidadesPorCaja : lote.precioCompraCaja
                        return acc + (consumo.cantidad * costoUnitario)
                    }
                }
            }
    }

    private var ingresosNetosHoy: Double { cobradasHoy + emitidasHoy }
    private var margenBruto: Double { ingresosNetosHoy - costoVentasHoy }
    private var porcentajeMargen: Double {
        ingresosNetosHoy > 0 ? (margenBruto / ingresosNetosHoy) * 100 : 0
    }

    // MARK: - Metricas de inventario

    private var entradasHoy: Double {
        movimientosHoy.filter { $0.tipoMovimiento == TipoMovimiento.entrada.rawValue }.reduce(0) { $0 + $1.cantidad }
    }

    private var salidasHoy: Double {
        movimientosHoy.filter { $0.tipoMovimiento == TipoMovimiento.salida.rawValue }.reduce(0) { $0 + $1.cantidad }
    }

    // MARK: - Top productos

    private var topProductos: [TopProducto] {
        var acumulado: [String: (cantidad: Double, ingresos: Double)] = [:]
        for venta in ventasHoy where venta.estadoFactura != EstadoFactura.anulada.rawValue {
            for detalle in venta.detalles {
                let nombre = detalle.producto?.nombre ?? "Sin producto"
                let existente = acumulado[nombre] ?? (cantidad: 0, ingresos: 0)
                acumulado[nombre] = (
                    cantidad: existente.cantidad + detalle.cantidad,
                    ingresos: existente.ingresos + detalle.subtotal
                )
            }
        }
        return acumulado
            .map { TopProducto(nombre: $0.key, cantidad: $0.value.cantidad, ingresos: $0.value.ingresos) }
            .sorted { $0.ingresos > $1.ingresos }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Empleado del dia

    private struct EmpleadoStats: Identifiable {
        let id = UUID()
        let nombre: String
        let facturas: Int
        let monto: Double
    }

    private var empleadoStats: [EmpleadoStats] {
        var stats: [String: (facturas: Int, monto: Double)] = [:]
        for venta in ventasHoy where venta.estadoFactura != EstadoFactura.anulada.rawValue {
            let nombre = venta.empleado?.nombre ?? "Sin empleado"
            let existente = stats[nombre] ?? (facturas: 0, monto: 0)
            stats[nombre] = (facturas: existente.facturas + 1, monto: existente.monto + venta.total)
        }
        return stats.map { EmpleadoStats(nombre: $0.key, facturas: $0.value.facturas, monto: $0.value.monto) }
            .sorted { $0.monto > $1.monto }
    }

    // MARK: - Alertas de caducidad

    private var lotesProximosCaducar: [LoteProducto] {
        let en30Dias = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return lotes.filter { lote in
            guard let fechaCaducidad = lote.fechaCaducidad else { return false }
            return fechaCaducidad <= en30Dias &&
                   fechaCaducidad > Date() &&
                   (lote.estadoLote == EstadoLote.vigente.rawValue || lote.estadoLote == EstadoLote.proximo.rawValue)
        }
    }

    private var lotesCaducados: [LoteProducto] {
        lotes.filter { lote in
            lote.estadoLote == EstadoLote.caducado.rawValue && lote.unidadesDisponibles > 0
        }
    }

    // MARK: - Charts

    private var chartMonetario: [ChartPoint] {
        [
            ChartPoint(nombre: "Cobrado", valor: cobradasHoy, color: .green),
            ChartPoint(nombre: "Por cobrar", valor: emitidasHoy, color: .orange),
            ChartPoint(nombre: "Costo", valor: costoVentasHoy, color: .red),
            ChartPoint(nombre: "Margen", valor: margenBruto, color: .blue)
        ]
    }

    private var chartInventario: [ChartPoint] {
        [
            ChartPoint(nombre: "Entradas", valor: entradasHoy, color: .teal),
            ChartPoint(nombre: "Salidas", valor: salidasHoy, color: .red)
        ]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                encabezado
                tarjetasResumen
                HStack(alignment: .top, spacing: 16) {
                    graficoMonetario
                    graficoInventario
                }
                HStack(alignment: .top, spacing: 16) {
                    seccionTopProductos
                    seccionEmpleados
                }
                if !lotesProximosCaducar.isEmpty || !lotesCaducados.isEmpty {
                    seccionAlertasCaducidad
                }
                if !movimientosHoy.isEmpty {
                    seccionActividadDelDia
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 620)
        .tiendaWindowBackground()
    }

    // MARK: - Subvistas

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("Reporte Diario", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Cierre del día con ventas, costos, margen, inventario y alertas de caducidad.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            DatePicker("", selection: $fechaReporte, displayedComponents: .date)
                .labelsHidden()
                .frame(width: 140)
            Text(ventasHoy.isEmpty ? "Sin actividad" : "\(ventasHoy.count) facturas")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .tiendaSecondaryGlass(cornerRadius: 14)
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private var tarjetasResumen: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            tarjeta("Facturas", "\(ventasHoy.count)", color: .blue)
            tarjeta("Cobrado", "$\(String(format: "%.2f", cobradasHoy))", color: .green)
            tarjeta("Por cobrar", "$\(String(format: "%.2f", emitidasHoy))", color: .orange)
            tarjeta("Costo ventas", "$\(String(format: "%.2f", costoVentasHoy))", color: .red)
            tarjeta("Margen bruto", "$\(String(format: "%.2f", margenBruto))", color: margenBruto >= 0 ? .blue : .red)
            tarjeta("% Margen", "\(String(format: "%.1f", porcentajeMargen))%", color: porcentajeMargen >= 20 ? .green : .orange)
            tarjeta("Anuladas", "\(anuladasHoy)", color: anuladasHoy > 0 ? .red : .secondary)
            tarjeta("Entradas", "\(String(format: "%.0f", entradasHoy)) und", color: .teal)
            tarjeta("Salidas", "\(String(format: "%.0f", salidasHoy)) und", color: .red)
        }
    }

    private var graficoMonetario: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen monetario").font(.headline)
            if chartMonetario.allSatisfy({ $0.valor == 0 }) {
                Text("Sin movimientos monetarios hoy").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(chartMonetario) { punto in
                    BarMark(
                        x: .value("Tipo", punto.nombre),
                        y: .value("Monto", punto.valor)
                    )
                    .foregroundStyle(punto.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("$\(String(format: "%.0f", punto.valor))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var graficoInventario: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movimiento de inventario").font(.headline)
            if entradasHoy == 0 && salidasHoy == 0 {
                Text("Sin movimientos de inventario hoy").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(chartInventario) { punto in
                    BarMark(
                        x: .value("Tipo", punto.nombre),
                        y: .value("Unidades", punto.valor)
                    )
                    .foregroundStyle(punto.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("\(String(format: "%.0f", punto.valor)) und")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 240, height: 200)
            }
        }
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var seccionTopProductos: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top productos del día").font(.headline)
            if topProductos.isEmpty {
                Text("Sin ventas registradas").font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(topProductos) { producto in
                    HStack {
                        Text(producto.nombre).font(.subheadline)
                        Spacer()
                        Text("\(String(format: "%.0f", producto.cantidad)) und")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("$\(String(format: "%.2f", producto.ingresos))")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var seccionEmpleados: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rendimiento por empleado").font(.headline)
            if empleadoStats.isEmpty {
                Text("Sin actividad").font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(empleadoStats) { stat in
                    HStack {
                        Text(stat.nombre).font(.subheadline)
                        Spacer()
                        Text("\(stat.facturas) facturas")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("$\(String(format: "%.2f", stat.monto))")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var seccionAlertasCaducidad: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Alertas de caducidad").font(.headline)
                Spacer()
                if !lotesCaducados.isEmpty {
                    Text("\(lotesCaducados.count) caducados")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.red.opacity(0.12), in: Capsule())
                }
                if !lotesProximosCaducar.isEmpty {
                    Text("\(lotesProximosCaducar.count) próximos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            ForEach(lotesCaducados.prefix(5), id: \.persistentModelID) { lote in
                alertaLote(lote, tipo: "CADUCADO", color: .red)
            }
            ForEach(lotesProximosCaducar.prefix(5), id: \.persistentModelID) { lote in
                let dias = Calendar.current.dateComponents([.day], from: Date(), to: lote.fechaCaducidad ?? Date()).day ?? 0
                alertaLote(lote, tipo: "Caduca en \(dias) días", color: .orange)
            }
        }
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var seccionActividadDelDia: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actividad del día").font(.headline)
            ForEach(movimientosHoy.prefix(15), id: \.persistentModelID) { movimiento in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movimiento.producto?.nombre ?? "Sin producto")
                            .font(.subheadline)
                        Text(movimiento.concepto)
                            .font(.caption).foregroundStyle(.secondary)
                        if let empleado = movimiento.empleado {
                            Text(empleado.nombre)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(String(format: "%.0f", movimiento.cantidad)) und")
                        .font(.caption.weight(.semibold))
                    Text(movimiento.tipoMovimiento)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(movimiento.tipoMovimiento == TipoMovimiento.entrada.rawValue ? .green : .red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((movimiento.tipoMovimiento == TipoMovimiento.entrada.rawValue ? Color.green : Color.red).opacity(0.12), in: Capsule())
                    Text(movimiento.fecha, format: .dateTime.hour().minute())
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .tiendaSecondaryGlass(cornerRadius: 18)
            }
        }
        .padding(18)
        .tiendaGlassCard(cornerRadius: 24)
    }

    // MARK: - Helpers

    private func tarjeta(_ titulo: String, _ valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text(valor).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func alertaLote(_ lote: LoteProducto, tipo: String, color: Color) -> some View {
        HStack {
            Text(lote.producto?.nombre ?? "Sin producto")
                .font(.subheadline)
            Text("Lote \(lote.idLote)")
                .font(.caption).foregroundStyle(.secondary)
            if let fecha = lote.fechaCaducidad {
                Text(fecha, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(String(format: "%.0f", lote.unidadesDisponibles)) und")
                .font(.caption.weight(.semibold))
            Text(tipo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(color.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .tiendaSecondaryGlass(cornerRadius: 14)
    }
}

#Preview {
    ReporteDiarioView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self, PromocionProducto.self, CuentaContable.self, AsientoContable.self, DetalleAsientoContable.self], inMemory: true)
}
