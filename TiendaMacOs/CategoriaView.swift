//
//  CategoriaView.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
//

import SwiftUI
import SwiftData

struct CategoriaView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    
    @State private var viewModelo: CategoriaViewModel?
    @State private var nombreCategoria = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Título
            Text("Categorías")
                .font(.largeTitle)
                .bold()
            
            // Panel de agregar nueva categoría
            HStack {
                TextField("Nueva categoría", text: $nombreCategoria)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)
                
                Button(action: {
                    viewModelo?.guadarCategoria(nombre: nombreCategoria)
                    nombreCategoria = ""
                }) {
                    Label("Agregar", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Lista de categorías
            List(categorias) { categoria in
                HStack {
                    Text(categoria.nombre)
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        viewModelo?.eliminarCategoria(categoria: categoria)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless) // importante en macOS
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            if viewModelo == nil {
                viewModelo = CategoriaViewModel(ModelConext: modelContext)
            }
        }
    }
}

#Preview {
    CategoriaView()
        .modelContainer(for: [Categoria.self])
}

