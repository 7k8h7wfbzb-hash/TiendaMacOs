//
//  FacturaPDFDocument.swift
//  TiendaMacOs
//

import SwiftUI
import UniformTypeIdentifiers

struct FacturaPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum FacturaPDFExporter {
    @MainActor
    static func makeDocument(for venta: Venta) -> FacturaPDFDocument? {
        let renderer = ImageRenderer(
            content: FacturaPreviewView(venta: venta)
                .frame(width: 720, height: 980)
        )

        let mutableData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return nil
        }

        context.beginPDFPage(nil)
        renderer.render { size, renderInContext in
            let printableRect = mediaBox.insetBy(dx: 24, dy: 24)
            let scale = min(printableRect.width / size.width, printableRect.height / size.height)
            let renderedWidth = size.width * scale
            let renderedHeight = size.height * scale
            let originX = printableRect.minX + ((printableRect.width - renderedWidth) / 2)
            let originY = printableRect.maxY - ((printableRect.height - renderedHeight) / 2)

            context.saveGState()
            context.translateBy(x: originX, y: originY)
            context.scaleBy(x: scale, y: -scale)
            renderInContext(context)
            context.restoreGState()
        }
        context.endPDFPage()
        context.closePDF()

        return FacturaPDFDocument(data: mutableData as Data)
    }
}
