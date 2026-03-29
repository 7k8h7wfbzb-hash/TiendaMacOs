//
//  FacturaPreviewView.swift
//  TiendaMacOs
//

import SwiftData
import SwiftUI

struct FacturaPreviewView: View {
    let venta: Venta

    private var detallesOrdenados: [DetalleVenta] {
        venta.detalles.sorted { ($0.producto?.nombre ?? "") < ($1.producto?.nombre ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                encabezado
                informacionGeneral
                detalleTabla
                resumen
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var encabezado: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Factura")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(venta.numeroFactura)
                    .font(.title3.weight(.semibold))
                Text("Estado: \(venta.estadoFactura)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(venta.fecha, format: .dateTime.day().month().year())
                if let fechaPago = venta.fechaPago {
                    Text("Pago: \(fechaPago, format: .dateTime.day().month().year().hour().minute())")
                }
                if let metodoPago = venta.metodoPago, !metodoPago.isEmpty {
                    Text("Metodo: \(metodoPago)")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var informacionGeneral: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cliente")
                    .font(.headline)
                Text(venta.cliente?.nombre ?? "Sin cliente")
                Text(venta.cliente?.cedula ?? "")
                    .foregroundStyle(.secondary)
                Text(venta.cliente?.telefono ?? "")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Empleado")
                    .font(.headline)
                Text(venta.empleado?.nombre ?? "Sin empleado")
                Text(venta.empleado?.cargo ?? "")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detalleTabla: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detalle")
                .font(.headline)

            ForEach(detallesOrdenados, id: \.persistentModelID) { detalle in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detalle.producto?.nombre ?? "Sin producto")
                            .fontWeight(.medium)
                        Text("\(String(format: "%.0f", detalle.cantidad)) x $\(String(format: "%.2f", detalle.precioUnitarioSnapshot))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(String(format: "%.2f", detalle.subtotal))")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 10)
                Divider()
            }
        }
    }

    private var resumen: some View {
        VStack(alignment: .trailing, spacing: 8) {
            resumenFila("Subtotal", valor: venta.subtotal)
            resumenFila("Impuesto", valor: venta.impuesto)
            resumenFila("Total", valor: venta.total, destacado: true)

            if let motivo = venta.motivoAnulacion, !motivo.isEmpty {
                Divider()
                Text("Motivo de anulacion: \(motivo)")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func resumenFila(_ titulo: String, valor: Double, destacado: Bool = false) -> some View {
        HStack {
            Text(titulo)
                .font(destacado ? .headline : .body)
            Spacer()
            Text("$\(String(format: "%.2f", valor))")
                .font(destacado ? .headline : .body)
        }
        .frame(maxWidth: 260)
    }
}

#Preview {
    Text("Preview")
}
