import Charts
import SwiftData
import SwiftUI

private enum SeccionContabilidad: String, CaseIterable, Identifiable {
    case resumen = "Resumen"
    case planCuentas = "Plan de Cuentas"
    case diarioGeneral = "Diario General"
    case libroMayor = "Libro Mayor"
    case balanceComprobacion = "Balance de Comprobación"
    case estadoResultados = "Estado de Resultados"
    case balanceGeneral = "Balance General"

    var id: String { rawValue }

    var icono: String {
        switch self {
        case .resumen: return "chart.pie.fill"
        case .planCuentas: return "list.bullet.rectangle.fill"
        case .diarioGeneral: return "book.fill"
        case .libroMayor: return "text.book.closed.fill"
        case .balanceComprobacion: return "scalemass.fill"
        case .estadoResultados: return "chart.line.uptrend.xyaxis"
        case .balanceGeneral: return "building.columns.fill"
        }
    }
}

private struct ChartPoint: Identifiable {
    let id = UUID()
    let nombre: String
    let valor: Double
}

struct ContabilidadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \AsientoContable.fecha, order: .reverse) private var asientos: [AsientoContable]
    @Query(sort: \CuentaContable.codigo) private var cuentas: [CuentaContable]

    @State private var viewModel: ContabilidadViewModel?
    @State private var seccionActiva: SeccionContabilidad = .resumen
    @State private var mensajeError = ""
    @State private var mostrarError = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                barraNavegacion
                seccionContenido
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 620)
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

    // MARK: - Navegacion de secciones

    private var barraNavegacion: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SeccionContabilidad.allCases) { seccion in
                    Button {
                        seccionActiva = seccion
                    } label: {
                        Label(seccion.rawValue, systemImage: seccion.icono)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(seccionActiva == seccion ? Color.indigo.opacity(0.2) : Color.clear)
                            .tiendaSecondaryGlass(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .tiendaGlassCard(cornerRadius: 22)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var seccionContenido: some View {
        switch seccionActiva {
        case .resumen:
            SeccionResumenView(asientos: asientos, cuentas: cuentas)
        case .planCuentas:
            SeccionPlanCuentasView(cuentas: cuentas, viewModel: viewModel, onError: presentar)
        case .diarioGeneral:
            SeccionDiarioGeneralView(asientos: asientos, cuentas: cuentas, viewModel: viewModel, onError: presentar)
        case .libroMayor:
            SeccionLibroMayorView(cuentas: cuentas)
        case .balanceComprobacion:
            SeccionBalanceComprobacionView(cuentas: cuentas)
        case .estadoResultados:
            SeccionEstadoResultadosView(cuentas: cuentas)
        case .balanceGeneral:
            SeccionBalanceGeneralView(cuentas: cuentas)
        }
    }

    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

// MARK: - 1. Resumen

private struct SeccionResumenView: View {
    let asientos: [AsientoContable]
    let cuentas: [CuentaContable]

    private var totalDebitos: Double { asientos.reduce(0) { $0 + $1.totalDebito } }
    private var totalCreditos: Double { asientos.reduce(0) { $0 + $1.totalCredito } }

    private var cuentasResumen: [ChartPoint] {
        cuentas
            .filter { abs($0.saldoActual) > 0.01 }
            .prefix(8)
            .map { ChartPoint(nombre: "\($0.codigo) \($0.nombre)", valor: $0.saldoActual) }
    }

    private var ingresosVsGastos: [ChartPoint] {
        let ingresos = cuentas.filter { $0.tipo == TipoCuenta.ingreso.rawValue }.reduce(0) { $0 + $1.saldoActual }
        let gastos = cuentas.filter { $0.tipo == TipoCuenta.gasto.rawValue }.reduce(0) { $0 + $1.saldoActual }
        return [
            ChartPoint(nombre: "Ingresos", valor: ingresos),
            ChartPoint(nombre: "Gastos", valor: gastos)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    estadisticaCard(valor: "\(cuentas.count)", titulo: "cuentas")
                    estadisticaCard(valor: "\(asientos.count)", titulo: "asientos")
                    estadisticaCard(valor: "$\(String(format: "%.2f", totalDebitos))", titulo: "débitos")
                    estadisticaCard(valor: "$\(String(format: "%.2f", totalCreditos))", titulo: "créditos")
                    let balance = abs(totalDebitos - totalCreditos)
                    estadisticaCard(
                        valor: balance < 0.01 ? "OK" : "$\(String(format: "%.2f", balance))",
                        titulo: balance < 0.01 ? "balanceado" : "desbalance"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Saldos principales")
                            .font(.headline)
                        if cuentasResumen.isEmpty {
                            Text("Sin movimientos aún").font(.subheadline).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            Chart(cuentasResumen) { punto in
                                BarMark(
                                    x: .value("Cuenta", punto.nombre),
                                    y: .value("Saldo", punto.valor)
                                )
                                .foregroundStyle(punto.valor >= 0 ? Color.blue : Color.orange)
                                .cornerRadius(6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                        }
                    }
                    .padding(18)
                    .tiendaSecondaryGlass(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingresos vs Gastos")
                            .font(.headline)
                        Chart(ingresosVsGastos) { punto in
                            BarMark(
                                x: .value("Tipo", punto.nombre),
                                y: .value("Monto", punto.valor)
                            )
                            .foregroundStyle(punto.nombre == "Ingresos" ? Color.green : Color.red)
                            .cornerRadius(6)
                        }
                        .frame(width: 260, height: 220)
                    }
                    .padding(18)
                    .tiendaSecondaryGlass(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Cobertura contable")
                            .font(.headline)
                        coberturaChip("Compras por lote", color: .teal)
                        coberturaChip("Ventas emitidas", color: .orange)
                        coberturaChip("Cobros de factura", color: .green)
                        coberturaChip("Anulaciones", color: .red)
                        coberturaChip("Pagos a proveedor", color: .indigo)
                        coberturaChip("Liquidación IVA", color: .purple)
                        coberturaChip("Asientos manuales", color: .cyan)
                    }
                    .frame(width: 220, alignment: .leading)
                    .padding(18)
                    .tiendaSecondaryGlass(cornerRadius: 22)
                }

                // Ultimos asientos
                VStack(alignment: .leading, spacing: 12) {
                    Text("Últimos movimientos")
                        .font(.headline)
                    if asientos.isEmpty {
                        Text("Aún no hay asientos contables registrados.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(asientos.prefix(5), id: \.persistentModelID) { asiento in
                            filaAsiento(asiento)
                        }
                    }
                }
                .padding(18)
                .tiendaGlassCard(cornerRadius: 24)
            }
            .padding(.horizontal, 4)
        }
    }

    private func filaAsiento(_ asiento: AsientoContable) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(asiento.concepto).font(.headline)
                Text("\(asiento.referencia) • \(asiento.modulo)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("D $\(String(format: "%.2f", asiento.totalDebito))")
                .font(.caption).foregroundStyle(.green)
            Text("C $\(String(format: "%.2f", asiento.totalCredito))")
                .font(.caption).foregroundStyle(.red)
            Text(asiento.fecha, format: .dateTime.day().month().year())
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private func estadisticaCard(valor: String, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valor).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(titulo).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func coberturaChip(_ texto: String, color: Color) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - 2. Plan de Cuentas

private struct SeccionPlanCuentasView: View {
    let cuentas: [CuentaContable]
    let viewModel: ContabilidadViewModel?
    let onError: (Error) -> Void

    @State private var codigoNueva = ""
    @State private var nombreNueva = ""
    @State private var tipoNueva = TipoCuenta.activo
    @State private var cuentaAEliminar: CuentaContable?
    @State private var mostrarConfirmacion = false

    var body: some View {
        VStack(spacing: 16) {
            // Formulario
            HStack(spacing: 12) {
                campo("Código", texto: $codigoNueva, ancho: 100)
                campo("Nombre de la cuenta", texto: $nombreNueva, ancho: nil)
                Picker("Tipo", selection: $tipoNueva) {
                    ForEach(TipoCuenta.allCases, id: \.self) { tipo in
                        Text(tipo.rawValue).tag(tipo)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                .padding(.horizontal, 12).padding(.vertical, 12)
                .tiendaSecondaryGlass(cornerRadius: 16)
                Button {
                    do {
                        try viewModel?.crearCuenta(codigo: codigoNueva, nombre: nombreNueva, tipo: tipoNueva.rawValue)
                        codigoNueva = ""
                        nombreNueva = ""
                    } catch { onError(error) }
                } label: {
                    Label("Agregar", systemImage: "plus").fontWeight(.semibold)
                }
                .tiendaPrimaryButton()
                .disabled(codigoNueva.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          nombreNueva.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .tiendaGlassCard(cornerRadius: 22)

            // Tabla
            Table(cuentas) {
                TableColumn("Código") { cuenta in
                    Text(cuenta.codigo).font(.system(.body, design: .monospaced))
                }
                .width(min: 70, ideal: 90)
                TableColumn("Cuenta") { cuenta in
                    Text(cuenta.nombre).font(.headline)
                }
                TableColumn("Tipo") { cuenta in
                    Text(cuenta.tipo)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colorTipoCuenta(cuenta.tipo))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(colorTipoCuenta(cuenta.tipo).opacity(0.12), in: Capsule())
                }
                .width(min: 100, ideal: 130)
                TableColumn("Saldo") { cuenta in
                    Text("$\(String(format: "%.2f", cuenta.saldoActual))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(cuenta.saldoActual >= 0 ? Color.primary : Color.red)
                }
                .width(min: 100, ideal: 120)
                TableColumn("Estado") { cuenta in
                    Button {
                        do { try viewModel?.toggleActivaCuenta(cuenta) }
                        catch { onError(error) }
                    } label: {
                        Text(cuenta.activa ? "Activa" : "Inactiva")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(cuenta.activa ? .green : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((cuenta.activa ? Color.green : Color.gray).opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .width(min: 80, ideal: 90)
                TableColumn("") { cuenta in
                    Button {
                        cuentaAEliminar = cuenta
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(!cuenta.movimientos.isEmpty)
                }
                .width(44)
            }
            .tableStyle(.inset)
        }
        .confirmationDialog("Eliminar cuenta", isPresented: $mostrarConfirmacion) {
            Button("Eliminar", role: .destructive) {
                if let cuenta = cuentaAEliminar {
                    do { try viewModel?.eliminarCuenta(cuenta) }
                    catch { onError(error) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func campo(_ titulo: String, texto: Binding<String>, ancho: CGFloat?) -> some View {
        TextField(titulo, text: texto)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: ancho.map { CGFloat($0) } ?? .infinity)
            .tiendaSecondaryGlass(cornerRadius: 16)
    }

    private func colorTipoCuenta(_ tipo: String) -> Color {
        switch tipo {
        case TipoCuenta.activo.rawValue: return .blue
        case TipoCuenta.pasivo.rawValue: return .red
        case TipoCuenta.patrimonio.rawValue: return .purple
        case TipoCuenta.ingreso.rawValue: return .green
        case TipoCuenta.gasto.rawValue: return .orange
        default: return .secondary
        }
    }
}

// MARK: - 3. Diario General

private struct SeccionDiarioGeneralView: View {
    let asientos: [AsientoContable]
    let cuentas: [CuentaContable]
    let viewModel: ContabilidadViewModel?
    let onError: (Error) -> Void

    @State private var fechaDesde = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var fechaHasta = Date()
    @State private var busqueda = ""

    // Asiento manual
    @State private var conceptoManual = ""
    @State private var lineasManuales: [LineaAsientoManual] = [LineaAsientoManual(), LineaAsientoManual()]
    @State private var mostrarFormulario = false
    @State private var asientoAEliminar: AsientoContable?
    @State private var mostrarConfirmacion = false

    private var asientosFiltrados: [AsientoContable] {
        asientos.filter { asiento in
            asiento.fecha >= fechaDesde && asiento.fecha <= fechaHasta &&
            (busqueda.isEmpty ||
             asiento.concepto.localizedCaseInsensitiveContains(busqueda) ||
             asiento.referencia.localizedCaseInsensitiveContains(busqueda))
        }
    }

    private var totalDebitoManual: Double { lineasManuales.reduce(0) { $0 + $1.debito } }
    private var totalCreditoManual: Double { lineasManuales.reduce(0) { $0 + $1.credito } }
    private var estaBalanceado: Bool { abs(totalDebitoManual - totalCreditoManual) < 0.01 && totalDebitoManual > 0 }

    var body: some View {
        VStack(spacing: 12) {
            // Filtros
            HStack(spacing: 12) {
                DatePicker("Desde", selection: $fechaDesde, displayedComponents: .date)
                    .labelsHidden().frame(width: 130)
                DatePicker("Hasta", selection: $fechaHasta, displayedComponents: .date)
                    .labelsHidden().frame(width: 130)
                TextField("Buscar...", text: $busqueda)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: 220)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                Spacer()
                Text("\(asientosFiltrados.count) asientos")
                    .font(.caption).foregroundStyle(.secondary)
                Button(mostrarFormulario ? "Cerrar formulario" : "Asiento manual") {
                    mostrarFormulario.toggle()
                }
                .tiendaPrimaryButton()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .tiendaGlassCard(cornerRadius: 22)

            // Formulario asiento manual
            if mostrarFormulario {
                formularioAsientoManual
            }

            // Lista
            List {
                ForEach(asientosFiltrados, id: \.persistentModelID) { asiento in
                    filaAsientoCompleta(asiento)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.inset(alternatesRowBackgrounds: false))
        }
        .confirmationDialog("Eliminar asiento manual", isPresented: $mostrarConfirmacion) {
            Button("Eliminar", role: .destructive) {
                if let asiento = asientoAEliminar {
                    do { try viewModel?.eliminarAsiento(asiento) }
                    catch { onError(error) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var formularioAsientoManual: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Nuevo asiento manual")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("D: $\(String(format: "%.2f", totalDebitoManual))").font(.caption).foregroundStyle(.green)
                    Text("C: $\(String(format: "%.2f", totalCreditoManual))").font(.caption).foregroundStyle(.red)
                    Image(systemName: estaBalanceado ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(estaBalanceado ? .green : .orange)
                }
            }

            TextField("Concepto del asiento", text: $conceptoManual)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .tiendaSecondaryGlass(cornerRadius: 14)

            ForEach($lineasManuales) { $linea in
                HStack(spacing: 8) {
                    Picker("Cuenta", selection: $linea.codigoCuenta) {
                        Text("Seleccionar cuenta").tag("")
                        ForEach(cuentas.filter(\.activa), id: \.persistentModelID) { cuenta in
                            Text("\(cuenta.codigo) - \(cuenta.nombre)").tag(cuenta.codigo)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    TextField("Débito", value: $linea.debito, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 100)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .tiendaSecondaryGlass(cornerRadius: 10)
                    TextField("Crédito", value: $linea.credito, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 100)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .tiendaSecondaryGlass(cornerRadius: 10)
                    Button {
                        lineasManuales.removeAll { $0.id == linea.id }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(lineasManuales.count <= 2)
                }
            }

            HStack {
                Button("Agregar línea") {
                    lineasManuales.append(LineaAsientoManual())
                }
                .tiendaSecondaryButton()
                Spacer()
                Button("Registrar asiento") {
                    do {
                        try viewModel?.crearAsientoManual(concepto: conceptoManual, lineas: lineasManuales)
                        conceptoManual = ""
                        lineasManuales = [LineaAsientoManual(), LineaAsientoManual()]
                        mostrarFormulario = false
                    } catch { onError(error) }
                }
                .tiendaPrimaryButton()
                .disabled(!estaBalanceado || conceptoManual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .tiendaGlassCard(cornerRadius: 22)
    }

    private func filaAsientoCompleta(_ asiento: AsientoContable) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(asiento.concepto).font(.headline)
                    HStack(spacing: 8) {
                        Text(asiento.referencia)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(asiento.modulo)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.12), in: Capsule())
                        if let empleado = asiento.empleado {
                            Text(empleado.nombre)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(asiento.fecha, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                if asiento.esManual {
                    Button {
                        asientoAEliminar = asiento
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red).padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(asiento.detalles, id: \.persistentModelID) { detalle in
                HStack {
                    Text(detalle.cuenta?.codigo ?? "")
                        .font(.caption.weight(.medium)).frame(width: 50, alignment: .leading)
                    Text(detalle.cuenta?.nombre ?? "Cuenta sin asignar")
                        .font(.subheadline)
                    Spacer()
                    if detalle.debito > 0 {
                        Text("$\(String(format: "%.2f", detalle.debito))")
                            .font(.caption.weight(.semibold)).foregroundStyle(.green)
                    }
                    if detalle.credito > 0 {
                        Text("$\(String(format: "%.2f", detalle.credito))")
                            .font(.caption.weight(.semibold)).foregroundStyle(.red)
                            .padding(.leading, detalle.debito > 0 ? 8 : 0)
                    }
                }
                .padding(.leading, 16)
            }

            HStack {
                Image(systemName: asiento.estaBalanceado ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(asiento.estaBalanceado ? .teal : .orange)
                Text(asiento.estaBalanceado ? "Balanceado" : "Desbalanceado")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(asiento.estaBalanceado ? .teal : .orange)
                Spacer()
                Text("D $\(String(format: "%.2f", asiento.totalDebito))")
                    .font(.caption.weight(.semibold))
                Text("C $\(String(format: "%.2f", asiento.totalCredito))")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .tiendaSecondaryGlass(cornerRadius: 20)
    }
}

// MARK: - 4. Libro Mayor

private struct FilaLibroMayor: Identifiable {
    let id = UUID()
    let fecha: Date
    let concepto: String
    let referencia: String
    let debito: Double
    let credito: Double
    let saldoAcumulado: Double
}

private struct SeccionLibroMayorView: View {
    let cuentas: [CuentaContable]

    @State private var cuentaSeleccionada: CuentaContable?
    @State private var fechaDesde = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var fechaHasta = Date()

    private var movimientosFiltrados: [FilaLibroMayor] {
        guard let cuenta = cuentaSeleccionada else { return [] }
        let movimientos = cuenta.movimientos
            .filter { movimiento in
                guard let asiento = movimiento.asiento else { return false }
                return asiento.fecha >= fechaDesde && asiento.fecha <= fechaHasta
            }
            .sorted { lhs, rhs in
                (lhs.asiento?.fecha ?? .distantPast) < (rhs.asiento?.fecha ?? .distantPast)
            }

        let esCuentaAcreedora = [TipoCuenta.pasivo.rawValue, TipoCuenta.ingreso.rawValue, TipoCuenta.patrimonio.rawValue]
            .contains(cuenta.tipo)
        var saldo = 0.0
        return movimientos.map { detalle in
            if esCuentaAcreedora {
                saldo += detalle.credito - detalle.debito
            } else {
                saldo += detalle.debito - detalle.credito
            }
            return FilaLibroMayor(
                fecha: detalle.asiento?.fecha ?? Date(),
                concepto: detalle.asiento?.concepto ?? "",
                referencia: detalle.asiento?.referencia ?? "",
                debito: detalle.debito,
                credito: detalle.credito,
                saldoAcumulado: saldo
            )
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Cuenta", selection: $cuentaSeleccionada) {
                    Text("Seleccionar cuenta").tag(nil as CuentaContable?)
                    ForEach(cuentas, id: \.persistentModelID) { cuenta in
                        Text("\(cuenta.codigo) - \(cuenta.nombre)").tag(Optional(cuenta))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 350)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .tiendaSecondaryGlass(cornerRadius: 16)
                DatePicker("Desde", selection: $fechaDesde, displayedComponents: .date).labelsHidden().frame(width: 130)
                DatePicker("Hasta", selection: $fechaHasta, displayedComponents: .date).labelsHidden().frame(width: 130)
                Spacer()
                if let cuenta = cuentaSeleccionada {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Saldo actual").font(.caption).foregroundStyle(.secondary)
                        Text("$\(String(format: "%.2f", cuenta.saldoActual))")
                            .font(.headline.weight(.bold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .tiendaSecondaryGlass(cornerRadius: 14)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .tiendaGlassCard(cornerRadius: 22)

            if cuentaSeleccionada == nil {
                estadoVacio(icono: "text.book.closed.fill", titulo: "Selecciona una cuenta", detalle: "Elige una cuenta del catálogo para ver su libro mayor con todos los movimientos.")
            } else if movimientosFiltrados.isEmpty {
                estadoVacio(icono: "doc.text.magnifyingglass", titulo: "Sin movimientos", detalle: "La cuenta seleccionada no tiene movimientos en el rango de fechas indicado.")
            } else {
                Table(movimientosFiltrados) {
                    TableColumn("Fecha") { item in
                        Text(item.fecha, format: .dateTime.day().month().year())
                            .font(.caption)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Concepto") { item in
                        Text(item.concepto)
                    }
                    TableColumn("Referencia") { item in
                        Text(item.referencia)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .width(min: 120, ideal: 160)
                    TableColumn("Débito") { item in
                        Text(item.debito > 0 ? "$\(String(format: "%.2f", item.debito))" : "")
                            .font(.system(.body, design: .monospaced)).foregroundStyle(.green)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Crédito") { item in
                        Text(item.credito > 0 ? "$\(String(format: "%.2f", item.credito))" : "")
                            .font(.system(.body, design: .monospaced)).foregroundStyle(.red)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Saldo") { item in
                        Text("$\(String(format: "%.2f", item.saldoAcumulado))")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                    .width(min: 90, ideal: 110)
                }
                .tableStyle(.inset)
            }
        }
    }
}

// MARK: - 5. Balance de Comprobacion

private struct SeccionBalanceComprobacionView: View {
    let cuentas: [CuentaContable]
    @State private var fechaCorte = Date()

    private struct FilaBalance: Identifiable {
        let id: String
        let codigo: String
        let nombre: String
        let tipo: String
        let debitos: Double
        let creditos: Double
        let saldoDeudor: Double
        let saldoAcreedor: Double
    }

    private var filas: [FilaBalance] {
        let inicio = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date.distantPast
        return cuentas.compactMap { cuenta in
            let debitos = cuenta.debitosEnRango(desde: inicio, hasta: fechaCorte)
            let creditos = cuenta.creditosEnRango(desde: inicio, hasta: fechaCorte)
            guard debitos > 0.001 || creditos > 0.001 else { return nil }
            let neto = debitos - creditos
            return FilaBalance(
                id: cuenta.codigo,
                codigo: cuenta.codigo,
                nombre: cuenta.nombre,
                tipo: cuenta.tipo,
                debitos: debitos,
                creditos: creditos,
                saldoDeudor: max(neto, 0),
                saldoAcreedor: max(-neto, 0)
            )
        }
    }

    private var totalDebitos: Double { filas.reduce(0) { $0 + $1.debitos } }
    private var totalCreditos: Double { filas.reduce(0) { $0 + $1.creditos } }
    private var totalSaldoDeudor: Double { filas.reduce(0) { $0 + $1.saldoDeudor } }
    private var totalSaldoAcreedor: Double { filas.reduce(0) { $0 + $1.saldoAcreedor } }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Balance de Comprobación")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("Corte al:").font(.caption).foregroundStyle(.secondary)
                DatePicker("", selection: $fechaCorte, displayedComponents: .date)
                    .labelsHidden().frame(width: 130)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .tiendaGlassCard(cornerRadius: 22)

            if filas.isEmpty {
                estadoVacio(icono: "scalemass.fill", titulo: "Sin datos", detalle: "No hay movimientos contables registrados hasta la fecha de corte.")
            } else {
                Table(filas) {
                    TableColumn("Código") { fila in
                        Text(fila.codigo).font(.system(.body, design: .monospaced))
                    }
                    .width(min: 70, ideal: 80)
                    TableColumn("Cuenta") { fila in Text(fila.nombre) }
                    TableColumn("Tipo") { fila in
                        Text(fila.tipo).font(.caption).foregroundStyle(.secondary)
                    }
                    .width(min: 90, ideal: 100)
                    TableColumn("Débitos") { fila in
                        Text("$\(String(format: "%.2f", fila.debitos))")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 90, ideal: 110)
                    TableColumn("Créditos") { fila in
                        Text("$\(String(format: "%.2f", fila.creditos))")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 90, ideal: 110)
                    TableColumn("Saldo Deudor") { fila in
                        Text(fila.saldoDeudor > 0.001 ? "$\(String(format: "%.2f", fila.saldoDeudor))" : "")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 100, ideal: 110)
                    TableColumn("Saldo Acreedor") { fila in
                        Text(fila.saldoAcreedor > 0.001 ? "$\(String(format: "%.2f", fila.saldoAcreedor))" : "")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 100, ideal: 110)
                }
                .tableStyle(.inset)

                // Totales
                HStack {
                    Spacer()
                    totalCard("Total Débitos", valor: totalDebitos)
                    totalCard("Total Créditos", valor: totalCreditos)
                    totalCard("Saldo Deudor", valor: totalSaldoDeudor)
                    totalCard("Saldo Acreedor", valor: totalSaldoAcreedor)
                    Image(systemName: abs(totalSaldoDeudor - totalSaldoAcreedor) < 0.01 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(abs(totalSaldoDeudor - totalSaldoAcreedor) < 0.01 ? .green : .red)
                        .font(.title2)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .tiendaGlassCard(cornerRadius: 18)
            }
        }
    }

    private func totalCard(_ titulo: String, valor: Double) -> some View {
        VStack(spacing: 4) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text("$\(String(format: "%.2f", valor))")
                .font(.system(.headline, design: .monospaced).weight(.bold))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .tiendaSecondaryGlass(cornerRadius: 14)
    }
}

// MARK: - 6. Estado de Resultados

private struct SeccionEstadoResultadosView: View {
    let cuentas: [CuentaContable]
    @State private var fechaDesde = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var fechaHasta = Date()

    private var cuentasIngreso: [CuentaContable] {
        cuentas.filter { $0.tipo == TipoCuenta.ingreso.rawValue }
    }
    private var cuentasGasto: [CuentaContable] {
        cuentas.filter { $0.tipo == TipoCuenta.gasto.rawValue }
    }

    private var totalIngresos: Double {
        cuentasIngreso.reduce(0) { $0 + $1.saldoEnRango(desde: fechaDesde, hasta: fechaHasta) }
    }
    private var totalGastos: Double {
        cuentasGasto.reduce(0) { $0 + $1.saldoEnRango(desde: fechaDesde, hasta: fechaHasta) }
    }
    private var utilidadNeta: Double { totalIngresos - totalGastos }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Estado de Resultados")
                        .font(.title3.weight(.bold))
                    Spacer()
                    DatePicker("Desde", selection: $fechaDesde, displayedComponents: .date).labelsHidden().frame(width: 130)
                    Text("al").font(.caption).foregroundStyle(.secondary)
                    DatePicker("Hasta", selection: $fechaHasta, displayedComponents: .date).labelsHidden().frame(width: 130)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .tiendaGlassCard(cornerRadius: 22)

                // Ingresos
                seccionEstado(titulo: "INGRESOS", cuentas: cuentasIngreso, color: .green)

                // Gastos
                seccionEstado(titulo: "GASTOS", cuentas: cuentasGasto, color: .red)

                // Resultado final
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(utilidadNeta >= 0 ? "UTILIDAD NETA" : "PÉRDIDA NETA")
                            .font(.headline.weight(.bold))
                        Text("Ingresos $\(String(format: "%.2f", totalIngresos)) - Gastos $\(String(format: "%.2f", totalGastos))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(String(format: "%.2f", abs(utilidadNeta)))")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(utilidadNeta >= 0 ? .green : .red)
                }
                .padding(20)
                .background((utilidadNeta >= 0 ? Color.green : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .tiendaGlassCard(cornerRadius: 22)
            }
            .padding(.horizontal, 4)
        }
    }

    private func seccionEstado(titulo: String, cuentas: [CuentaContable], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                let total = cuentas.reduce(0) { $0 + $1.saldoEnRango(desde: fechaDesde, hasta: fechaHasta) }
                Text("$\(String(format: "%.2f", total))")
                    .font(.system(.headline, design: .monospaced).weight(.bold))
            }
            ForEach(cuentas, id: \.persistentModelID) { cuenta in
                let saldo = cuenta.saldoEnRango(desde: fechaDesde, hasta: fechaHasta)
                if abs(saldo) > 0.001 {
                    HStack {
                        Text(cuenta.codigo)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(cuenta.nombre)
                        Spacer()
                        Text("$\(String(format: "%.2f", saldo))")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .tiendaGlassCard(cornerRadius: 22)
    }
}

// MARK: - 7. Balance General

private struct SeccionBalanceGeneralView: View {
    let cuentas: [CuentaContable]
    @State private var fechaCorte = Date()

    private var activos: [CuentaContable] { cuentas.filter { $0.tipo == TipoCuenta.activo.rawValue } }
    private var pasivos: [CuentaContable] { cuentas.filter { $0.tipo == TipoCuenta.pasivo.rawValue } }
    private var patrimonio: [CuentaContable] { cuentas.filter { $0.tipo == TipoCuenta.patrimonio.rawValue } }

    private var totalActivos: Double { activos.reduce(0) { $0 + $1.saldoAlCorte(fechaCorte) } }
    private var totalPasivos: Double { pasivos.reduce(0) { $0 + $1.saldoAlCorte(fechaCorte) } }
    private var totalPatrimonio: Double { patrimonio.reduce(0) { $0 + $1.saldoAlCorte(fechaCorte) } }

    // Utilidad acumulada (ingresos - gastos al corte)
    private var utilidadAcumulada: Double {
        let ingresos = cuentas.filter { $0.tipo == TipoCuenta.ingreso.rawValue }
            .reduce(0) { $0 + $1.saldoAlCorte(fechaCorte) }
        let gastos = cuentas.filter { $0.tipo == TipoCuenta.gasto.rawValue }
            .reduce(0) { $0 + $1.saldoAlCorte(fechaCorte) }
        return ingresos - gastos
    }

    private var totalPasivoMasPatrimonio: Double { totalPasivos + totalPatrimonio + utilidadAcumulada }
    private var cuadra: Bool { abs(totalActivos - totalPasivoMasPatrimonio) < 0.01 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Balance General")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("Al:").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $fechaCorte, displayedComponents: .date)
                        .labelsHidden().frame(width: 130)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .tiendaGlassCard(cornerRadius: 22)

                HStack(alignment: .top, spacing: 16) {
                    // Activos
                    seccionBalance(titulo: "ACTIVOS", cuentas: activos, total: totalActivos, color: .blue)

                    VStack(spacing: 16) {
                        // Pasivos
                        seccionBalance(titulo: "PASIVOS", cuentas: pasivos, total: totalPasivos, color: .red)
                        // Patrimonio
                        seccionBalance(titulo: "PATRIMONIO", cuentas: patrimonio, total: totalPatrimonio, color: .purple)
                        // Utilidad acumulada
                        if abs(utilidadAcumulada) > 0.001 {
                            HStack {
                                Text("Utilidad del ejercicio")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("$\(String(format: "%.2f", utilidadAcumulada))")
                                    .font(.system(.body, design: .monospaced).weight(.bold))
                                    .foregroundStyle(utilidadAcumulada >= 0 ? .green : .red)
                            }
                            .padding(14)
                            .tiendaSecondaryGlass(cornerRadius: 16)
                        }
                    }
                }

                // Ecuacion contable
                HStack(spacing: 16) {
                    ecuacionCard("Activos", valor: totalActivos, color: .blue)
                    Text("=").font(.title2.weight(.bold))
                    ecuacionCard("Pasivos", valor: totalPasivos, color: .red)
                    Text("+").font(.title2.weight(.bold))
                    ecuacionCard("Patrimonio", valor: totalPatrimonio + utilidadAcumulada, color: .purple)
                    Spacer()
                    Image(systemName: cuadra ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(cuadra ? .green : .orange)
                    Text(cuadra ? "Cuadrado" : "Descuadrado")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(cuadra ? .green : .orange)
                }
                .padding(20)
                .tiendaGlassCard(cornerRadius: 22)
            }
            .padding(.horizontal, 4)
        }
    }

    private func seccionBalance(titulo: String, cuentas: [CuentaContable], total: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                Text("$\(String(format: "%.2f", total))")
                    .font(.system(.headline, design: .monospaced).weight(.bold))
            }
            ForEach(cuentas, id: \.persistentModelID) { cuenta in
                let saldo = cuenta.saldoAlCorte(fechaCorte)
                if abs(saldo) > 0.001 {
                    HStack {
                        Text(cuenta.codigo)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(cuenta.nombre)
                        Spacer()
                        Text("$\(String(format: "%.2f", saldo))")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
            }
            if cuentas.allSatisfy({ abs($0.saldoAlCorte(fechaCorte)) < 0.001 }) {
                Text("Sin movimientos al corte")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(18)
        .tiendaGlassCard(cornerRadius: 22)
    }

    private func ecuacionCard(_ titulo: String, valor: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(titulo).font(.caption).foregroundStyle(color)
            Text("$\(String(format: "%.2f", valor))")
                .font(.system(.headline, design: .monospaced).weight(.bold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .tiendaSecondaryGlass(cornerRadius: 14)
    }
}

// MARK: - Helper compartido

private func estadoVacio(icono: String, titulo: String, detalle: String) -> some View {
    VStack(spacing: 16) {
        Image(systemName: icono)
            .font(.system(size: 42))
            .foregroundStyle(.indigo)
            .padding(18)
            .tiendaSecondaryGlass(cornerRadius: 22)
        Text(titulo)
            .font(.title3.weight(.bold))
        Text(detalle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
    .tiendaGlassCard(cornerRadius: 28)
}

#Preview {
    ContabilidadView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self, PromocionProducto.self, CuentaContable.self, AsientoContable.self, DetalleAsientoContable.self], inMemory: true)
}
