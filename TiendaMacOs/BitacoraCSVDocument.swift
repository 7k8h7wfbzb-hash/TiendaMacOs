//
//  BitacoraCSVDocument.swift
//  TiendaMacOs
//

import SwiftUI
import UniformTypeIdentifiers

struct BitacoraCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    let data: Data
    
    init(csv: String) {
        self.data = Data(csv.utf8)
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
