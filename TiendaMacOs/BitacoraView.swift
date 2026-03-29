//
//  BitacoraView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BitacoraView: View {
    @Query(sort: \RegistroOperacion.fecha, order: .reverse) private var operaciones: [RegistroOperacion]
    @Query(sort: \Empleado.nombre) private var empleados: [Empleado]
    
    @State private var moduloSeleccionado = "Todos"
    @State private var empleadoSeleccionadoID: PersistentIdentifier?
    @State private var busqueda = ""
    @State private var fechaInicio = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var fechaFin = Date()
    @State private var mostrarExporterCSV = false
    @State private var documentoCSV: BitacoraCSVDocument?
    
    private var modulosDisponibles: [String] {
        let modulos = Set(operaciones.map(\.modulo)).sorted()
        return ["Todos"] + modulos
    }
    
    private var operacionesFiltradas: [RegistroOperacion] {
        operaciones.filter { operacion in
            let coincideModulo = moduloSeleccionado == "Todos" || operacion.modulo == moduloSeleccionado
            let coincideEmpleado = empleadoSeleccionadoID == nil || operacion.empleado?.persistentModelID == empleadoSeleccionadoID
            let inicio = Calendar.current.startOfDay(for: fechaInicio)
            let fin = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: fechaFin) ?? fechaFin
            let coincideFecha = operacion.fecha >= inicio && operacion.fecha <= fin
            let texto = busqueda.trimmingCharacters(in: .whitespacesAndNewlines)
            let coincideBusqueda =
                texto.isEmpty ||
                operacion.accion.localizedCaseInsensitiveContains(texto) ||
                operacion.detalle.localizedCaseInsensitiveContains(texto) ||
                operacion.modulo.localizedCaseInsensitiveContains(texto) ||
                (operacion.empleado?.nombre.localizedCaseInsensitiveContains(texto) ?? false)
            
            return coincideModulo && coincideEmpleado && coincideFecha && coincideBusqueda
        }
    }
    
    private var operacionesHoy: Int {
        let inicio = Calendar.current.startOfDay(for: Date())
        return operaciones.filter { $0.fecha >= inicio }.count
    }
    
    private var operacionesSeguridad: Int {
        operaciones.filter { $0.modulo == "Seguridad" }.count
    }
    
    private var empleadosActivosHoy: Int {
        let inicio = Calendar.current.startOfDay(for: Date())
        let ids = Set(
            operaciones
                .filter { $0.fecha >= inicio }
                .compactMap { $0.empleado?.persistentModelID }
        )
        return ids.count
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado
                if operacionesFiltradas.isEmpty {
                    estadoVacio
                } else {
                    listaOperaciones
                }
            }
        }
        .padding(20)
        .frame(minWidth: 920, minHeight: 620)
        .tiendaWindowBackground()
        .fileExporter(
            isPresented: $mostrarExporterCSV,
            document: documentoCSV,
            contentType: .commaSeparatedText,
            defaultFilename: nombreArchivoCSV
        ) { _ in
            documentoCSV = nil
        }
    }
    
    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bitacora de Operaciones", systemImage: "list.clipboard.fill")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Consulta la auditoria del sistema para saber quien hizo cada operacion, en que modulo y en que momento.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        card(valor: "\(operaciones.count)", titulo: "registros")
                        card(valor: "\(operacionesHoy)", titulo: "hoy")
                        card(valor: "\(empleadosActivosHoy)", titulo: "empleados activos")
                        card(valor: "\(operacionesSeguridad)", titulo: "seguridad")
                    }
                }
                
                HStack(spacing: 12) {
                    heroPanel(
                        titulo: "Trazabilidad real",
                        detalle: "Cada operacion registra modulo, empleado, fecha y detalle operativo.",
                        color: .orange
                    )
                    heroPanel(
                        titulo: "Control interno",
                        detalle: "Filtra por responsable, fechas y modulo para revisar decisiones con contexto.",
                        color: .cyan
                    )
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Picker("Modulo", selection: $moduloSeleccionado) {
                            ForEach(modulosDisponibles, id: \.self) { modulo in
                                Text(modulo).tag(modulo)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                        
                        Picker("Empleado", selection: $empleadoSeleccionadoID) {
                            Text("Todos los empleados").tag(nil as PersistentIdentifier?)
                            ForEach(empleados, id: \.persistentModelID) { empleado in
                                Text(empleado.nombre).tag(Optional(empleado.persistentModelID))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Buscar en accion, detalle o empleado", text: $busqueda)
                                .textFieldStyle(.plain)
                                .frame(width: 260)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .tiendaSecondaryGlass(cornerRadius: 16)
                        
                        DatePicker("Desde", selection: $fechaInicio, displayedComponents: .date)
                            .labelsHidden()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .tiendaSecondaryGlass(cornerRadius: 16)
                        
                        DatePicker("Hasta", selection: $fechaFin, displayedComponents: .date)
                            .labelsHidden()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .tiendaSecondaryGlass(cornerRadius: 16)
                        
                        Button("Exportar CSV") {
                            documentoCSV = BitacoraCSVDocument(csv: construirCSV())
                            mostrarExporterCSV = documentoCSV != nil
                        }
                        .tiendaPrimaryButton()
                        
                        Button("Limpiar filtros") {
                            moduloSeleccionado = "Todos"
                            empleadoSeleccionadoID = nil
                            busqueda = ""
                            fechaInicio = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                            fechaFin = Date()
                        }
                        .tiendaSecondaryButton()
                    }
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }
    
    private var listaOperaciones: some View {
        Table(operacionesFiltradas) {
            TableColumn("Fecha") { operacion in
                Text(operacion.fecha, format: .dateTime.day().month().year().hour().minute())
            }
            TableColumn("Modulo") { operacion in
                Text(operacion.modulo)
            }
            TableColumn("Accion") { operacion in
                Text(operacion.accion)
                    .font(.headline)
            }
            TableColumn("Empleado") { operacion in
                Text(operacion.empleado?.nombre ?? "Sin empleado")
            }
            TableColumn("Detalle") { operacion in
                Text(operacion.detalle)
                    .lineLimit(2)
            }
            TableColumn("Estado") { operacion in
                Text(Calendar.current.isDateInToday(operacion.fecha) ? "Hoy" : "Historico")
            }
        }
        .tableStyle(.inset)
    }
    
    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)
            Text("No hay registros para este filtro")
                .font(.title3.weight(.bold))
            Text("Cuando los empleados realicen operaciones en el sistema, la bitacora mostrara aqui la auditoria detallada.")
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
        .tiendaSurfaceHighlight(cornerRadius: 18)
    }
    
    private func badge(_ texto: String) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .tiendaSecondaryGlass(cornerRadius: 12)
    }
    
    private func colorModulo(for modulo: String) -> Color {
        switch modulo {
        case "Ventas":
            return .pink
        case "Lotes":
            return .teal
        case "Productos":
            return .indigo
        case "Empleados":
            return .green
        case "Clientes":
            return .blue
        case "Proveedores":
            return .mint
        case "Categorias":
            return .orange
        case "Seguridad":
            return .red
        default:
            return .secondary
        }
    }
    
    private var nombreArchivoCSV: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "bitacora-\(formatter.string(from: fechaInicio))-\(formatter.string(from: fechaFin))"
    }
    
    private func construirCSV() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let encabezado = "fecha,modulo,accion,empleado,detalle"
        let filas = operacionesFiltradas.map { operacion in
            let fecha = formatter.string(from: operacion.fecha)
            let modulo = escaparCSV(operacion.modulo)
            let accion = escaparCSV(operacion.accion)
            let empleado = escaparCSV(operacion.empleado?.nombre ?? "Sin empleado")
            let detalle = escaparCSV(operacion.detalle)
            return "\(fecha),\(modulo),\(accion),\(empleado),\(detalle)"
        }
        
        return ([encabezado] + filas).joined(separator: "\n")
    }
    
    private func escaparCSV(_ texto: String) -> String {
        let limpio = texto.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(limpio)\""
    }
    
    private func heroPanel(titulo: String, detalle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(color.opacity(0.16))
                .overlay(Image(systemName: "clock.arrow.circlepath").foregroundStyle(color))
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
}

#Preview {
    BitacoraView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
