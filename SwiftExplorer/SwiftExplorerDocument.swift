import SwiftUI
import UniformTypeIdentifiers
import SwiftParser
import SwiftSyntax
import SwiftExplorerMacros

//extension UTType {
//    static var exampleText: UTType {
//        UTType(importedAs: "com.example.plain-text")
//    }
//}

struct SwiftExplorerDocument: FileDocument {
    var text: String

    var compiled: SourceFileSyntax?

    init(text: String = "Hello, world!") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.swiftSource] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }

    mutating func compile() {
        compiled = Parser.parse(source: text)
    }
}
