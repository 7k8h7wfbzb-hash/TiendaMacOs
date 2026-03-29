//
//  KardexView.swift
//  TiendaMacOs
//

import Charts
import SwiftData
import SwiftUI

private struct KardexChartPoint: Identifiable {
    let id = UUID()
    let fecha: Date
    let tipo: String
    let cantidad: Double
}

private struct KardexResumenPoint: Identifiable {
    let id = UUID()
    let titulo: String
    let valor: Double
    let color: Color
}

struct KardexView: View {
    @Query(sort: \Kardex.fecha, order: .reverse) private var movimientos: [Kardex]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @State private var categoriaFiltroPadre: Categoria?
    @State private var subcategoriaFiltro: Categoria?

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

    private var movimientosFiltrados: [Kardex] {
        movimientos.filter { movimiento in
            guard let categoriaFiltroPadre else { return true }
            let categoriaMovimiento = movimiento.producto?.categoria
            if let subcategoriaFiltro {
                return categoriaMovimiento?.persistentModelID == subcategoriaFiltro.persistentModelID
            }
            if categoriaFiltroPadre.subcategorias.isEmpty {
                return categoriaMovimiento?.persistentModelID == categoriaFiltroPadre.persistentModelID
            }
            return categoriaMovimiento?.categoriaPadre?.persistentModelID == categoriaFiltroPadre.persistentModelID
        }
    }

    private var totalEntradas: Double {
        movimientosFiltrados
            .filter { $0.tipoMovimiento.uppercased() == "ENTRADA" }
            .reduce(0) { $0 + $1.cantidad }
    }

    private var totalSalidas: Double {
        movimientosFiltrados
            .filter { $0.tipoMovimiento.uppercased() == "SALIDA" }
            .reduce(0) { $0 + $1.cantidad }
    }

    private var balanceInventario: Double {
        totalEntradas - totalSalidas
    }

    private var movimientosHoy: Int {
        let inicioDelDia = Calendar.current.startOfDay(for: Date())
        return movimientosFiltrados.filter { $0.fecha >= inicioDelDia }.count
    }

    private var ultimoMovimiento: Kardex? {
        movimientosFiltrados.first
    }

    private var movimientosUltimosSieteDias: [KardexChartPoint] {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())

        return (0..<7).flatMap { desplazamiento -> [KardexChartPoint] in
            let fecha = calendario.date(byAdding: .day, value: -6 + desplazamiento, to: hoy) ?? hoy
            let siguiente = calendario.date(byAdding: .day, value: 1, to: fecha) ?? fecha
            let movimientosDia = movimientosFiltrados.filter { $0.fecha >= fecha && $0.fecha < siguiente }
            let entradas = movimientosDia
                .filter { $0.tipoMovimiento.uppercased() == "ENTRADA" }
                .reduce(0) { $0 + $1.cantidad }
            let salidas = movimientosDia
                .filter { $0.tipoMovimiento.uppercased() == "SALIDA" }
                .reduce(0) { $0 + $1.cantidad }

            return [
                KardexChartPoint(fecha: fecha, tipo: "Entradas", cantidad: entradas),
                KardexChartPoint(fecha: fecha, tipo: "Salidas", cantidad: salidas)
            ]
        }
    }

    private var resumenMovimientoPoints: [KardexResumenPoint] {
        [
            KardexResumenPoint(titulo: "Entradas", valor: totalEntradas, color: .green),
            KardexResumenPoint(titulo: "Salidas", valor: totalSalidas, color: .red),
            KardexResumenPoint(titulo: "Balance", valor: balanceInventario, color: balanceInventario >= 0 ? .teal : .orange)
        ]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if movimientos.isEmpty {
                    estadoVacio
                } else {
                    listaMovimientos
                }
            }
        }
        .padding(20)
        .frame(minWidth: 840, minHeight: 560)
        .tiendaWindowBackground()
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
                        Label("Kardex Automatico", systemImage: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 30, weight: .bold, design: .rounded))

                        Text("Las entradas se generan al registrar lotes y las salidas aparecen al guardar detalles de venta. Aqui solo consultas el historial.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(movimientosFiltrados.count)", titulo: "movimientos")
                        estadisticaCard(valor: String(format: "%.0f", totalEntradas), titulo: "unidades entrada")
                        estadisticaCard(valor: String(format: "%.0f", totalSalidas), titulo: "unidades salida")
                    }
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
                    heroPanel(
                        titulo: "Balance operativo",
                        detalle: "El kardex deja ver si el flujo reciente esta mas cargado hacia entradas o salidas.",
                        color: balanceInventario >= 0 ? .teal : .orange
                    )
                    heroPanel(
                        titulo: "Actividad inmediata",
                        detalle: ultimoMovimiento.map { "Ultimo movimiento: \($0.tipoMovimiento.lowercased()) de \($0.producto?.nombre ?? "producto")" } ?? "Aun no hay actividad reciente registrada.",
                        color: .cyan
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    graficoKardex
                    graficoResumen
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaMovimientos: some View {
        GlassEffectContainer(spacing: 16) {
            Table(movimientosFiltrados) {
                TableColumn("Fecha") { movimiento in
                    Text(movimiento.fecha, format: .dateTime.day().month().year().hour().minute())
                }
                TableColumn("Producto") { movimiento in
                    Text(movimiento.producto?.nombre ?? "Producto sin asignar")
                        .font(.headline)
                }
                TableColumn("Categoria") { movimiento in
                    Text(movimiento.producto?.categoria?.nombreCompleto ?? "Sin categoria")
                }
                TableColumn("Tipo") { movimiento in
                    Text(movimiento.tipoMovimiento)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colorMovimiento(for: movimiento))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(colorMovimiento(for: movimiento).opacity(0.12), in: Capsule())
                }
                TableColumn("Cantidad") { movimiento in
                    Text("\(String(format: "%.0f", movimiento.cantidad))")
                }
                TableColumn("Costo") { movimiento in
                    Text("$\(String(format: "%.2f", movimiento.costoUnitarioEnEseMomento))")
                }
                TableColumn("Responsable") { movimiento in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(movimiento.empleado?.nombre ?? "Sin empleado")
                        Text(movimiento.fecha, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Concepto") { movimiento in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(movimiento.concepto)
                        Text(movimiento.producto?.categoria?.nombreCompleto ?? "Sin categoria")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tableStyle(.inset)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.teal)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)

            Text("Aun no hay movimientos")
                .font(.title3.weight(.bold))

            Text("Cuando ingreses lotes o registres ventas, el kardex se llenara automaticamente.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .tiendaGlassCard(cornerRadius: 28)
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 120, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func heroPanel(titulo: String, detalle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(color)
                )
            Text(titulo)
                .font(.headline)
            Text(detalle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private var graficoKardex: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flujo de inventario ultimos 7 dias")
                .font(.headline)

            Chart(movimientosUltimosSieteDias) { punto in
                BarMark(
                    x: .value("Fecha", punto.fecha, unit: .day),
                    y: .value("Cantidad", punto.cantidad)
                )
                .foregroundStyle(by: .value("Tipo", punto.tipo))
                .position(by: .value("Tipo", punto.tipo))
                .cornerRadius(6)
            }
            .chartForegroundStyleScale([
                "Entradas": Color.green,
                "Salidas": Color.red
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private var graficoResumen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen visual")
                .font(.headline)

            Chart(resumenMovimientoPoints) { punto in
                BarMark(
                    x: .value("Tipo", punto.titulo),
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
            .frame(width: 260, height: 200)

            HStack(spacing: 10) {
                quickInsightChip("Hoy \(movimientosHoy)", color: .cyan)
                quickInsightChip(balanceInventario >= 0 ? "Saldo positivo" : "Saldo ajustado", color: balanceInventario >= 0 ? .teal : .orange)
            }
        }
        .padding(18)
        .tiendaSecondaryGlass(cornerRadius: 22)
    }

    private func quickInsightChip(_ texto: String, color: Color) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
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
        .help("Filtrar movimientos por categoria principal")
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

    private func badge(texto: String, color: Color) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }

    private func colorMovimiento(for movimiento: Kardex) -> Color {
        movimiento.tipoMovimiento.uppercased() == "ENTRADA" ? .green : .red
    }

    private func iconoMovimiento(for movimiento: Kardex) -> String {
        movimiento.tipoMovimiento.uppercased() == "ENTRADA" ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }
}

#Preview {
    KardexView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
