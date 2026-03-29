//
//  AppGlassStyle.swift
//  TiendaMacOs
//

import SwiftUI

extension View {
    @ViewBuilder
    func tiendaWindowBackground() -> some View {
        if #available(macOS 26.0, *) {
            self
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.14, blue: 0.22),
                                Color(red: 0.11, green: 0.23, blue: 0.30),
                                Color(red: 0.16, green: 0.20, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.28),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 460
                        )
                        RadialGradient(
                            colors: [
                                Color.mint.opacity(0.20),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 40,
                            endRadius: 520
                        )
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 260, height: 260)
                            .blur(radius: 80)
                            .offset(x: 90, y: -120)
                    }
                    .overlay(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 90, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 320, height: 220)
                            .blur(radius: 90)
                            .offset(x: -80, y: 110)
                    }
                )
        } else {
            self
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.95, blue: 0.98),
                                Color(red: 0.80, green: 0.90, blue: 0.92),
                                Color(red: 0.91, green: 0.93, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.16), Color.clear],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 420
                        )
                        RadialGradient(
                            colors: [Color.teal.opacity(0.12), Color.clear],
                            center: .bottomTrailing,
                            startRadius: 20,
                            endRadius: 420
                        )
                    }
                )
        }
    }

    @ViewBuilder
    func tiendaGlassCard(cornerRadius: CGFloat = 24) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 24, y: 12)
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 20, y: 10)
        }
    }

    @ViewBuilder
    func tiendaSecondaryGlass(cornerRadius: CGFloat = 18) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
        }
    }
    
    func tiendaSurfaceHighlight(cornerRadius: CGFloat = 20) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

extension Button {
    @ViewBuilder
    func tiendaPrimaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .tint(Color.cyan.opacity(0.9))
        } else {
            self
                .buttonStyle(.borderedProminent)
                .tint(Color.teal)
        }
    }

    @ViewBuilder
    func tiendaSecondaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
