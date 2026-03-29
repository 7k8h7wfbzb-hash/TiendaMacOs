//
//  LoginView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EmployeeSession.self) private var employeeSession
    @Query(sort: \Empleado.nombre) private var empleados: [Empleado]
    
    @State private var usuario = ""
    @State private var pin = ""
    @State private var nombrePrimerEmpleado = ""
    @State private var cargoPrimerEmpleado = "Administrador"
    @State private var usuarioPrimerEmpleado = ""
    @State private var pinPrimerEmpleado = ""
    @State private var mensajeError = ""
    @State private var mostrarError = false
    @State private var modo: ModoAcceso = .login
    
    private enum ModoAcceso {
        case login
        case registro
    }
    
    private var hayEmpleados: Bool {
        !empleados.isEmpty
    }
    
    private var hayEmpleadosConAcceso: Bool {
        empleados.contains {
            !$0.usuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.pinAcceso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private var mostrarFormularioRegistro: Bool {
        !hayEmpleadosConAcceso || modo == .registro
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 22) {
                panelMarca
                VStack(spacing: 24) {
                    encabezado
                    selectorModo
                    if mostrarFormularioRegistro {
                        formularioPrimerAcceso
                    } else {
                        formularioLogin
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(28)
            .frame(width: 860)
            .tiendaGlassCard(cornerRadius: 32)
            .tiendaSurfaceHighlight(cornerRadius: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tiendaWindowBackground()
        .alert("Acceso no completado", isPresented: $mostrarError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeError)
        }
        .onAppear {
            sincronizarModo()
        }
        .onChange(of: empleados.count) {
            sincronizarModo()
        }
    }
    
    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mostrarFormularioRegistro ? "Registro de acceso" : "Bienvenido de nuevo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Label("Acceso de empleados", systemImage: "person.crop.circle.badge.checkmark")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(mostrarFormularioRegistro ? "Crea un empleado con usuario y PIN para poder entrar al sistema. Si ya tenias empleados antiguos sin credenciales, puedes completarlo desde aqui." : "Inicia sesion para registrar cada operacion con el empleado autenticado.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var selectorModo: some View {
        HStack(spacing: 12) {
            if hayEmpleadosConAcceso {
                Button {
                    modo = .login
                } label: {
                    Text("Iniciar sesion")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(modo == .login ? Color.white.opacity(0.18) : Color.clear)
                        .tiendaSecondaryGlass(cornerRadius: 18)
                        .tiendaSurfaceHighlight(cornerRadius: 18)
                }
                .buttonStyle(.plain)
            }
            
            Button {
                modo = .registro
            } label: {
                Text(hayEmpleados ? "Crear empleado" : "Primer acceso")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(mostrarFormularioRegistro ? Color.white.opacity(0.18) : Color.clear)
                    .tiendaSecondaryGlass(cornerRadius: 18)
                    .tiendaSurfaceHighlight(cornerRadius: 18)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var panelMarca: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.26),
                                Color.cyan.opacity(0.18),
                                Color.mint.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.white)
                    Text("Tienda OS")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Facturacion, inventario y auditoria en una sola consola.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.90))
                    VStack(alignment: .leading, spacing: 10) {
                        ventaja("Ventas con detalle y kardex automatico")
                        ventaja("Auditoria por empleado en tiempo real")
                        ventaja("Bitacora exportable para control interno")
                    }
                }
                .foregroundStyle(.white)
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 310)
            
            HStack(spacing: 10) {
                estadoPill(texto: hayEmpleados ? "\(empleados.count) empleados registrados" : "Primer acceso")
                estadoPill(texto: "Modo seguro")
            }
        }
    }
    
    private var formularioLogin: some View {
        VStack(spacing: 16) {
            campo("Usuario", icono: "person.fill", texto: $usuario)
            SecureField("PIN", text: $pin)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .tiendaSecondaryGlass(cornerRadius: 18)
                .tiendaSurfaceHighlight(cornerRadius: 18)
            Button("Ingresar") {
                do {
                    try employeeSession.iniciarSesion(usuario: usuario, pin: pin, modelContext: modelContext)
                    pin = ""
                } catch {
                    presentar(error)
                }
            }
            .tiendaPrimaryButton()
            .disabled(usuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            HStack(spacing: 10) {
                estadoPill(texto: "Sesion auditada")
                estadoPill(texto: "Registro por empleado")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var formularioPrimerAcceso: some View {
        VStack(spacing: 16) {
            campo("Nombre completo", icono: "person.text.rectangle.fill", texto: $nombrePrimerEmpleado)
            campo("Cargo", icono: "briefcase.fill", texto: $cargoPrimerEmpleado)
            campo("Usuario", icono: "at", texto: $usuarioPrimerEmpleado)
            SecureField("PIN", text: $pinPrimerEmpleado)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .tiendaSecondaryGlass(cornerRadius: 18)
                .tiendaSurfaceHighlight(cornerRadius: 18)
            Button(hayEmpleados ? "Registrar y entrar" : "Crear acceso inicial") {
                do {
                    if hayEmpleados {
                        try employeeSession.registrarEmpleado(
                            nombre: nombrePrimerEmpleado,
                            cargo: cargoPrimerEmpleado,
                            usuario: usuarioPrimerEmpleado,
                            pin: pinPrimerEmpleado,
                            modelContext: modelContext
                        )
                    } else {
                        try employeeSession.registrarPrimerEmpleado(
                            nombre: nombrePrimerEmpleado,
                            cargo: cargoPrimerEmpleado,
                            usuario: usuarioPrimerEmpleado,
                            pin: pinPrimerEmpleado,
                            modelContext: modelContext
                        )
                    }
                } catch {
                    presentar(error)
                }
            }
            .tiendaPrimaryButton()
            .disabled(
                nombrePrimerEmpleado.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                cargoPrimerEmpleado.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                usuarioPrimerEmpleado.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                pinPrimerEmpleado.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }
    
    private func campo(_ titulo: String, icono: String, texto: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(.secondary)
            TextField(titulo, text: texto)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .tiendaSecondaryGlass(cornerRadius: 18)
        .tiendaSurfaceHighlight(cornerRadius: 18)
    }
    
    private func ventaja(_ texto: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text(texto)
                .font(.subheadline.weight(.medium))
        }
    }
    
    private func estadoPill(texto: String) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .tiendaSecondaryGlass(cornerRadius: 14)
            .tiendaSurfaceHighlight(cornerRadius: 14)
    }
    
    private func presentar(_ error: Error) {
        mensajeError = error.localizedDescription
        mostrarError = true
    }
    
    private func sincronizarModo() {
        modo = hayEmpleadosConAcceso ? .login : .registro
    }
}

#Preview {
    LoginView()
        .environment(EmployeeSession())
        .modelContainer(for: [Empleado.self, RegistroOperacion.self], inMemory: true)
}
