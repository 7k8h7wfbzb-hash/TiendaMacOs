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
    @State private var mostrarConfirmacion: Bool = false
    @State private var categoriaElegida: Categoria?
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack{
                VStack(alignment: .leading,spacing: 4){
                    Text("Gestion de Categorias").font(.system(size: 22,weight: .bold,design: .rounded))
                    Text("\(categorias.count) categorias en total")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                HStack {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    TextField("Nueva Categoria", text: $nombreCategoria)
                        .textFieldStyle(.plain)
                    
                    
                }.padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2),lineWidth: 1)
                    )
                Button("Agregar"){
                    viewModelo?.guardarCategoria(nombre: nombreCategoria)
                    nombreCategoria = ""
                } .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .help(Text("Agrega una nueva categoria"))
                    .disabled(nombreCategoria.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(20)
                .background(Material.ultraThick
                )
        Divider()
            if categorias.isEmpty {
                ContentUnavailableView(
                    "Sin Categorías",
                    systemImage: "folder.badge.plus",
                    description: Text("Empieza agregando una categoría arriba.")
                ) // cierre ContentUnavailableView
                
            } else {
                List{
                    ForEach(categorias,id: \.persistentModelID){ categoria in
                        HStack(spacing:20){
                            ZStack{
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "archivebox").foregroundStyle(.blue)
                                    
                                Text(categoria.nombre).font(.system(size: 14,weight: .medium))
                               
                            }
                            Spacer()
                            Button{
                                self.categoriaElegida = categoria
                                self.mostrarConfirmacion = true
                            }label: {
                                Image(systemName: "trash").font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }.padding(.vertical,6)
                        
                    }
                }.listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }.frame(minWidth:400,minHeight: 500)
            .confirmationDialog("Eleminar Categoria de forma permanente", isPresented: $mostrarConfirmacion){
                Button("Eliminar",role: .destructive){
                    if let cat  = categoriaElegida {
                        viewModelo?.eliminarCategoria(categoria: cat)
                    }
                }
                Button("cancelar",role:.cancel){
                    
                }
                Text("si eleminas \(categoriaElegida?.nombre ?? "") los productos asociación se perderán ")
            }
        
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

