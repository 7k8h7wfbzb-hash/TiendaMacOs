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
    
    @State private var nombreCategoria = ""
    @State private var viewModelo: CategoriaViewModel?

    var body: some View {
        VStack(spacing: 20) {
            
            Text("Categorías")
                .font(.largeTitle)
                .bold()
            
            HStack {
                TextField("Nueva categoría", text: $nombreCategoria)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)
                
                Button {
                    guard let vm = viewModelo else { return }
                    vm.guardarCategoria(nombre: nombreCategoria)
                    nombreCategoria = ""
                } label: {
                    Label("Agregar", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            Divider()
            
            List(categorias, id: \.self) { categoria in
                HStack {
                    Text(categoria.nombre)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        guard let vm = viewModelo else { return }
                        vm.eliminarCategoria(categoria: categoria)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
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
                viewModelo = CategoriaViewModel(modelContext: modelContext)
            }
        }
    }
}
#Preview {
    CategoriaView()
        .modelContainer(for: [Categoria.self])
}

