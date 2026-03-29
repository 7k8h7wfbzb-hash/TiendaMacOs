import Charts
import SwiftData
import SwiftUI

private struct ContabilidadResumenPoint: Identifiable {
    let id = UUID()
    let cuenta: String
    let saldo: Double
}

struct ContabilidadView: View {
    @Query(sort: \AsientoContable.fecha, order: .reverse) private var asientos: [AsientoContable]
    @Query(sort: \CuentaContable.codigo) private var cuentas: [CuentaContable]

    private var totalDebitos: Double {
        asientos.reduce(0) { $0 + $1.totalDebito }
    }

    private var totalCreditos: Double {
        asientos.reduce(0) { $0 + $1.totalCredito }
    }

    private var cuentasResumen: [ContabilidadResumenPoint] {
        cuentas
            .filter { abs($0.saldoActual) > 0.01 }
            .prefix(6)
            .map { ContabilidadResumenPoint(cuenta: "\($0.codigo) \($0.nombre)", saldo: $0.saldoActual) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                contenido
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 620)
        .tiendaWindowBackground()
    }

    private var encabezado: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Contabilidad", systemImage: "building.columns.fill")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Diario general inicial con catalogo de cuentas y asientos automaticos desde compras, ventas y cobros.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    estadisticaCard(valor: "\(cuentas.count)", titulo: "cuentas")
                    estadisticaCard(valor: "\(asientos.count)", titulo: "asientos")
                    estadisticaCard(valor: "$\(String(format: "%.2f", totalDebitos))", titulo: "debitos")
                    estadisticaCard(valor: "$\(String(format: "%.2f", totalCreditos))", titulo: "creditos")
                }
            }

            HStack(spacing: 12) {
                graficoSaldos
                resumenContable
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var contenido: some View {
        HStack(alignment: .top, spacing: 16) {
            catalogoCuentas
            diarioGeneral
        }
    }

    private var catalogoCuentas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalogo de cuentas")
                .font(.headline)

            Table(cuentas) {
                TableColumn("Codigo") { cuenta in
                    Text(cuenta.codigo)
                }
                TableColumn("Cuenta") { cuenta in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cuenta.nombre)
                            .font(.headline)
                        Text(cuenta.tipo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Saldo") { cuenta in
                    Text("$\(String(format: "%.2f", cuenta.saldoActual))")
                }
            }
            .tableStyle(.inset)
        }
        .padding(18)
        .frame(minWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .top)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var diarioGeneral: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diario general")
                .font(.headline)

            List {
                ForEach(asientos, id: \.persistentModelID) { asiento in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asiento.concepto)
                                    .font(.headline)
                                Text("\(asiento.referencia) • \(asiento.modulo)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(asiento.fecha, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(asiento.detalles, id: \.persistentModelID) { detalle in
                            HStack {
                                Text(detalle.cuenta?.nombre ?? "Cuenta sin asignar")
                                    .font(.subheadline)
                                Spacer()
                                Text("D $\(String(format: "%.2f", detalle.debito))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("C $\(String(format: "%.2f", detalle.credito))")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        HStack {
                            Text("Asiento balanceado")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(abs(asiento.totalDebito - asiento.totalCredito) < 0.01 ? .teal : .orange)
                            Spacer()
                            Text("D $\(String(format: "%.2f", asiento.totalDebito))")
                                .font(.caption.weight(.semibold))
                            Text("C $\(String(format: "%.2f", asiento.totalCredito))")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(14)
                    .tiendaSecondaryGlass(cornerRadius: 20)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.inset(alternatesRowBackgrounds: false))
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tiendaGlassCard(cornerRadius: 24)
    }

    private var graficoSaldos: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saldos principales")
                .font(.headline)

            Chart(cuentasResumen) { punto in
                BarMark(
                    x: .value("Cuenta", punto.cuenta),
                    y: .value("Saldo", punto.saldo)
                )
                .foregroundStyle(punto.saldo >= 0 ? Color.blue : Color.orange)
                .cornerRadius(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        }
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private var resumenContable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cobertura contable")
                .font(.headline)

            resumenChip("Compras por lote", color: .teal)
            resumenChip("Ventas emitidas", color: .orange)
            resumenChip("Cobros de factura", color: .green)
            resumenChip("Anulaciones", color: .red)
        }
        .frame(width: 240, alignment: .leading)
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
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

    private func resumenChip(_ texto: String, color: Color) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    ContabilidadView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self, PromocionProducto.self, CuentaContable.self, AsientoContable.self, DetalleAsientoContable.self], inMemory: true)
}
