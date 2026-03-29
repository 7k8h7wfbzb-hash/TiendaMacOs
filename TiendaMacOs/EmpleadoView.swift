//
//  EmpleadoView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct EmpleadoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Empleado.nombre) private var empleados: [Empleado]
    @Namespace private var glassNamespace

    @State private var viewModel: EmpleadoViewModel?
    @State private var nombre = ""
    @State private var cargo = ""
    @State private var usuario = ""
    @State private var pinAcceso = ""
    @State private var empleadoAEliminar: Empleado?
    @State private var empleadoSeleccionadoID: PersistentIdentifier?
    @State private var mostrarConfirmacion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @FocusState private var campoEnfocado: CampoFormulario?

    private enum CampoFormulario {
        case nombre
        case cargo
        case usuario
        case pin
    }

    private var nombreLimpio: String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cargoLimpio: String {
        cargo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var formularioValido: Bool {
        !nombreLimpio.isEmpty &&
        !cargoLimpio.isEmpty &&
        !usuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !pinAcceso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if empleados.isEmpty {
                    estadoVacio
                } else {
                    listaEmpleados
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520)
        .tiendaWindowBackground()
        .confirmationDialog(
            "Eliminar empleado",
            isPresented: $mostrarConfirmacion,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let empleado = empleadoAEliminar {
                    do {
                        try viewModel?.eliminarEmpleado(empleado: empleado)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminara \(empleadoAEliminar?.nombre ?? "este empleado") del registro.")
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onDeleteCommand(perform: eliminarEmpleadoSeleccionado)
        .onAppear {
            if viewModel == nil {
                viewModel = EmpleadoViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
            campoEnfocado = .nombre
        }
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gestion de Empleados", systemImage: "person.crop.rectangle.stack.fill")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Administra el equipo de trabajo con un registro claro de nombres y cargos dentro de la tienda.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(empleados.count)", titulo: empleados.count == 1 ? "empleado" : "empleados")
                            .glassEffectID("empleados-total", in: glassNamespace)

                        estadisticaCard(
                            valor: "\(Set(empleados.map(\.cargo)).count)",
                            titulo: "cargos"
                        )
                        .glassEffectID("empleados-cargos", in: glassNamespace)
                    }
                }

                HStack(spacing: 12) {
                    campoFormulario("Nombre", icono: "person.fill", texto: $nombre, foco: .nombre)
                        .glassEffectID("empleado-nombre", in: glassNamespace)

                    campoFormulario("Cargo", icono: "briefcase.fill", texto: $cargo, foco: .cargo)
                        .glassEffectID("empleado-cargo", in: glassNamespace)
                    
                    campoFormulario("Usuario", icono: "at", texto: $usuario, foco: .usuario)
                        .glassEffectID("empleado-usuario", in: glassNamespace)
                    
                    campoFormularioSeguro("PIN", icono: "lock.fill", texto: $pinAcceso, foco: .pin)
                        .glassEffectID("empleado-pin", in: glassNamespace)

                    Button("Nuevo") {
                        campoEnfocado = .nombre
                    }
                    .tiendaSecondaryButton()
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Enfocar el formulario de empleado. Atajo: Comando N")

                    Button {
                        guardarEmpleado()
                    } label: {
                        Label("Agregar", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                    }
                    .tiendaPrimaryButton()
                    .controlSize(.large)
                    .disabled(!formularioValido)
                    .glassEffectID("empleado-agregar", in: glassNamespace)
                    .keyboardShortcut(.return, modifiers: [])
                    .help("Guardar empleado. Atajo: Enter")
                }

                HStack(spacing: 10) {
                    atajoChip("⌘N", texto: "Enfocar nombre")
                    atajoChip("Enter", texto: "Avanzar o guardar")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaEmpleados: some View {
        GlassEffectContainer(spacing: 16) {
            Table(empleados, selection: $empleadoSeleccionadoID) {
                TableColumn("Nombre") { empleado in
                    Text(empleado.nombre)
                        .font(.headline)
                }
                TableColumn("Cargo") { empleado in
                    Text(empleado.cargo)
                }
                TableColumn("Usuario") { empleado in
                    Text(empleado.usuario)
                }
                TableColumn("Ventas") { empleado in
                    Text("\(empleado.ventas.count)")
                }
                TableColumn("Operaciones") { empleado in
                    Text("\(empleado.operaciones.count)")
                }
                TableColumn("Acceso") { empleado in
                    Text(empleado.pinAcceso.isEmpty ? "Sin acceso" : "Activo")
                        .foregroundStyle(empleado.pinAcceso.isEmpty ? .orange : .green)
                }
                TableColumn("") { empleado in
                    Button {
                        empleadoAEliminar = empleado
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Eliminar \(empleado.nombre)")
                }
                .width(44)
            }
            .tableStyle(.inset)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)

            Text("Aun no hay empleados")
                .font(.title3.weight(.bold))

            Text("Agrega a tu primer empleado con su nombre y cargo para empezar a organizar el equipo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                campoEnfocado = .nombre
            } label: {
                Label("Crear empleado", systemImage: "plus.circle.fill")
            }
            .tiendaPrimaryButton()
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
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tiendaSecondaryGlass(cornerRadius: 18)
    }

    private func campoFormulario(_ titulo: String, icono: String, texto: Binding<String>, foco: CampoFormulario) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.green)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
                .focused($campoEnfocado, equals: foco)
                .onSubmit {
                    avanzarFormulario(desde: foco)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .help("Presiona Enter para continuar")
    }
    
    private func campoFormularioSeguro(_ titulo: String, icono: String, texto: Binding<String>, foco: CampoFormulario) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.green)
            SecureField(titulo, text: texto)
                .textFieldStyle(.plain)
                .focused($campoEnfocado, equals: foco)
                .onSubmit {
                    avanzarFormulario(desde: foco)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .tiendaSecondaryGlass(cornerRadius: 16)
        .help("Presiona Enter para continuar")
    }

    private func infoBadge(icono: String, texto: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
            Text(texto)
                .lineLimit(1)
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

    private func avanzarFormulario(desde campo: CampoFormulario) {
        switch campo {
        case .nombre:
            campoEnfocado = .cargo
        case .cargo:
            campoEnfocado = .usuario
        case .usuario:
            campoEnfocado = .pin
        case .pin:
            guardarEmpleado()
        }
    }

    private func guardarEmpleado() {
        guard formularioValido else { return }

        let empleado = Empleado(
            nombre: nombreLimpio,
            cargo: cargoLimpio,
            usuario: usuario.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            pinAcceso: pinAcceso.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try viewModel?.guardarEmpleado(empleado: empleado)
        } catch {
            presentar(error)
            return
        }

        nombre = ""
        cargo = ""
        usuario = ""
        pinAcceso = ""
        campoEnfocado = .nombre
    }

    private func eliminarEmpleadoSeleccionado() {
        guard let empleadoSeleccionadoID,
              let empleado = empleados.first(where: { $0.persistentModelID == empleadoSeleccionadoID }) else { return }
        empleadoAEliminar = empleado
        mostrarConfirmacion = true
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
}

#Preview {
    EmpleadoView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
