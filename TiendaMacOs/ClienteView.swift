//
//  ClienteView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct ClienteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    @Namespace private var glassNamespace

    @State private var viewModel: ClienteViewModel?
    @State private var cedula = ""
    @State private var nombre = ""
    @State private var telefono = ""
    @State private var clienteAEliminar: Cliente?
    @State private var mostrarConfirmacion = false
    @FocusState private var campoEnfocado: CampoFormulario?

    private enum CampoFormulario {
        case cedula
        case nombre
        case telefono
    }

    private var cedulaLimpia: String {
        cedula.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nombreLimpio: String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var telefonoLimpio: String {
        telefono.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var formularioValido: Bool {
        !cedulaLimpia.isEmpty && !nombreLimpio.isEmpty && !telefonoLimpio.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                encabezado

                if clientes.isEmpty {
                    estadoVacio
                } else {
                    listaClientes
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520)
        .tiendaWindowBackground()
        .confirmationDialog(
            "Eliminar cliente",
            isPresented: $mostrarConfirmacion,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let cliente = clienteAEliminar {
                    try? viewModel?.eliminarCliente(cliente: cliente)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminara \(clienteAEliminar?.nombre ?? "este cliente") del registro.")
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ClienteViewModel(modelContext: modelContext)
            }
        }
    }

    private var encabezado: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gestion de Clientes", systemImage: "person.2.fill")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("Mantiene una cartera clara de clientes con sus datos de contacto y acceso rapido a su registro.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        estadisticaCard(valor: "\(clientes.count)", titulo: clientes.count == 1 ? "cliente" : "clientes")
                            .glassEffectID("clientes-total", in: glassNamespace)

                        estadisticaCard(
                            valor: "\(clientes.filter { !$0.telefono.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)",
                            titulo: "con telefono"
                        )
                        .glassEffectID("clientes-telefono", in: glassNamespace)
                    }
                }

                HStack(spacing: 12) {
                    campoFormulario("Cedula", icono: "number.square.fill", texto: $cedula, foco: .cedula)
                        .glassEffectID("cliente-cedula", in: glassNamespace)

                    campoFormulario("Nombre", icono: "person.fill", texto: $nombre, foco: .nombre)
                        .glassEffectID("cliente-nombre", in: glassNamespace)

                    campoFormulario("Telefono", icono: "phone.fill", texto: $telefono, foco: .telefono)
                        .glassEffectID("cliente-telefono", in: glassNamespace)

                    Button {
                        guardarCliente()
                    } label: {
                        Label("Agregar", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                    }
                    .tiendaPrimaryButton()
                    .controlSize(.large)
                    .disabled(!formularioValido)
                    .glassEffectID("cliente-agregar", in: glassNamespace)
                }
            }
        }
        .padding(20)
        .tiendaGlassCard(cornerRadius: 28)
        .padding(.bottom, 8)
    }

    private var listaClientes: some View {
        GlassEffectContainer(spacing: 16) {
            List {
                ForEach(clientes, id: \.persistentModelID) { cliente in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "person.fill")
                                .foregroundStyle(.orange)
                        }
                        .glassEffectID(cliente.persistentModelID, in: glassNamespace)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(cliente.nombre)
                                .font(.headline)

                            HStack(spacing: 10) {
                                infoBadge(icono: "person.text.rectangle.fill", texto: cliente.cedula)
                                infoBadge(icono: "phone.fill", texto: cliente.telefono)
                            }
                        }

                        Spacer()

                        Button {
                            clienteAEliminar = cliente
                            mostrarConfirmacion = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                        .tiendaSecondaryButton()
                        .help("Eliminar \(cliente.nombre)")
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
            .background(Color.clear)
            .listStyle(.inset(alternatesRowBackgrounds: false))
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .padding(18)
                .tiendaSecondaryGlass(cornerRadius: 22)

            Text("Aun no hay clientes")
                .font(.title3.weight(.bold))

            Text("Agrega tu primer cliente con cedula, nombre y telefono para empezar a registrar ventas de forma ordenada.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                campoEnfocado = .cedula
            } label: {
                Label("Crear cliente", systemImage: "plus.circle.fill")
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
                .foregroundStyle(.orange)
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
        case .cedula:
            campoEnfocado = .nombre
        case .nombre:
            campoEnfocado = .telefono
        case .telefono:
            guardarCliente()
        }
    }

    private func guardarCliente() {
        guard formularioValido else { return }

        let cliente = Cliente(cedula: cedulaLimpia, nombre: nombreLimpio, telefono: telefonoLimpio)
        try? viewModel?.guardarCliente(cliente: cliente)

        cedula = ""
        nombre = ""
        telefono = ""
        campoEnfocado = .cedula
    }
}

#Preview {
    ClienteView()
        .modelContainer(for: [Cliente.self], inMemory: true)
}
