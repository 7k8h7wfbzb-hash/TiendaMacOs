//
//  VistaProveedor.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//

import SwiftData
import SwiftUI

struct VistaProveedor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Proveedor.nombre) private var proveedores: [Proveedor]
    @Namespace private var glassNamespace

    @State private var viewModel: ProveedorViewModel?
    @State private var nombre = ""
    @State private var ruc = ""
    @State private var contacto = ""
    @State private var proveedorAEliminar: Proveedor?
    @State private var proveedorSeleccionadoID: PersistentIdentifier?
    @State private var mostrarConfirmacion = false
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @FocusState private var campoEnfocado: CampoFormulario?

    private enum CampoFormulario {
        case nombre
        case ruc
        case contacto
    }

    private var nombreLimpio: String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var rucLimpio: String {
        ruc.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contactoLimpio: String {
        contacto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var formularioValido: Bool {
        !nombreLimpio.isEmpty && !rucLimpio.isEmpty && !contactoLimpio.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if proveedores.isEmpty {
                    estadoVacio
                } else {
                    listaProveedores
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520)
        .tiendaWindowBackground()
        .confirmationDialog(
            "Eliminar proveedor",
            isPresented: $mostrarConfirmacion,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let proveedor = proveedorAEliminar {
                    do {
                        try viewModel?.eliminarProveedor(proveedor: proveedor)
                    } catch {
                        presentar(error)
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminara \(proveedorAEliminar?.nombre ?? "este proveedor") del registro.")
        }
        .alert("Operacion no completada", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onDeleteCommand(perform: eliminarProveedorSeleccionado)
        .onAppear {
            if viewModel == nil {
                viewModel = ProveedorViewModel(modelContext: modelContext, employeeSession: employeeSession)
            }
            campoEnfocado = .nombre
        }
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gestion de Proveedores", systemImage: "shippingbox.fill")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Registra los datos clave de cada proveedor para mantener compras y entregas mejor organizadas.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(proveedores.count)", titulo: proveedores.count == 1 ? "proveedor" : "proveedores")
                            .glassEffectID("proveedores-total", in: glassNamespace)

                        estadisticaCard(
                            valor: "\(proveedores.filter { !$0.contacto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)",
                            titulo: "con contacto"
                        )
                        .glassEffectID("proveedores-contacto", in: glassNamespace)
                    }
                }

                HStack(spacing: 12) {
                    campoFormulario("Nombre del proveedor", icono: "building.2.fill", texto: $nombre, foco: .nombre)
                        .glassEffectID("campo-nombre", in: glassNamespace)

                    campoFormulario("RUC", icono: "number.square.fill", texto: $ruc, foco: .ruc)
                        .glassEffectID("campo-ruc", in: glassNamespace)

                    campoFormulario("Contacto", icono: "person.crop.circle.fill", texto: $contacto, foco: .contacto)
                        .glassEffectID("campo-contacto", in: glassNamespace)

                    Button("Nuevo") {
                        campoEnfocado = .nombre
                    }
                    .tiendaSecondaryButton()
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Enfocar el formulario de proveedor. Atajo: Comando N")

                    Button {
                        guardarProveedor()
                    } label: {
                        Label("Agregar", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                    }
                    .tiendaPrimaryButton()
                    .controlSize(.large)
                    .disabled(!formularioValido)
                    .glassEffectID("agregar-proveedor", in: glassNamespace)
                    .keyboardShortcut(.return, modifiers: [])
                    .help("Guardar proveedor. Atajo: Enter")
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

    private var listaProveedores: some View {
        GlassEffectContainer(spacing: 16) {
            Table(proveedores, selection: $proveedorSeleccionadoID) {
                TableColumn("Proveedor") { proveedor in
                    Text(proveedor.nombre)
                        .font(.headline)
                }
                TableColumn("RUC") { proveedor in
                    Text(proveedor.ruc)
                }
                TableColumn("Contacto") { proveedor in
                    Text(proveedor.contacto)
                }
                TableColumn("Lotes") { proveedor in
                    Text("\(proveedor.lotesEntregados.count)")
                }
                TableColumn("Unidades") { proveedor in
                    Text("\(proveedor.lotesEntregados.reduce(0) { $0 + $1.totalUnidades }, format: .number.precision(.fractionLength(0)))")
                }
                TableColumn("") { proveedor in
                    Button {
                        proveedorAEliminar = proveedor
                        mostrarConfirmacion = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Eliminar \(proveedor.nombre)")
                }
                .width(44)
            }
            .tableStyle(.inset)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "tray.fill")
                .font(.system(size: 42))
                .foregroundStyle(.teal)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)

            Text("Aun no hay proveedores")
                .font(.title3.weight(.bold))

            Text("Agrega el primer proveedor con su nombre, RUC y contacto para empezar a registrar compras.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                campoEnfocado = .nombre
            } label: {
                Label("Crear proveedor", systemImage: "plus.circle.fill")
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
                .foregroundStyle(.teal)
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

    private func avanzarFormulario(desde campo: CampoFormulario) {
        switch campo {
        case .nombre:
            campoEnfocado = .ruc
        case .ruc:
            campoEnfocado = .contacto
        case .contacto:
            guardarProveedor()
        }
    }

    private func guardarProveedor() {
        guard formularioValido else { return }

        let proveedor = Proveedor(nombre: nombreLimpio, ruc: rucLimpio, contacto: contactoLimpio)
        do {
            try viewModel?.crearProveedor(proveedor: proveedor)
        } catch {
            presentar(error)
            return
        }

        nombre = ""
        ruc = ""
        contacto = ""
        campoEnfocado = .nombre
    }

    private func eliminarProveedorSeleccionado() {
        guard let proveedorSeleccionadoID,
              let proveedor = proveedores.first(where: { $0.persistentModelID == proveedorSeleccionadoID }) else { return }
        proveedorAEliminar = proveedor
        mostrarConfirmacion = true
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
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
}

#Preview {
    VistaProveedor()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, Cliente.self, Producto.self, LoteProducto.self, ConsumoLote.self, Categoria.self, Proveedor.self, Kardex.self, Venta.self, DetalleVenta.self, RegistroOperacion.self], inMemory: true)
}
