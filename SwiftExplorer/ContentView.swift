import SwiftUI
import SwiftSyntax
import Everything
import Observation

struct ContentView: View {
    @Binding var document: SwiftExplorerDocument

    @State
    var isInspectorPresented = true

    @State
    var syntaxSelection: Syntax?

    @State
    var textSelection: [Range<String.Index>] = []

    @State
    var allowUpdates = true

    var body: some View {
        VStack {
            SourceView(source: $document.text, selection: $textSelection)
            .font(.body.monospaced())
            HStack {
                if let syntaxSelection {
                    SyntaxPathView(syntax: Binding(get: { syntaxSelection }, set: { self.syntaxSelection = $0 }))
                }
                Spacer()
                Text("\(document.text.count)")
                .monospaced()
            }
            .padding([.leading, .trailing], 4)
            .padding([.bottom], 4)
        }
        .inspector(isPresented: $isInspectorPresented) {
            ZStack {
                if let syntax = document.compiled {
                    SyntaxView(syntax: syntax.as(Syntax.self)!, selection: $syntaxSelection)
                }
            }
            .inspectorColumnWidth(min: 200, ideal: 300, max: nil)
        }
        .toolbar {
            Button(action: { isInspectorPresented.toggle() }, label: { Image(systemName: "sidebar.right")})
        }
        .task {
            document.compile()
        }
        .onChange(of: syntaxSelection) {
            update {
                print("SYNTAX SELECTION DID CHANGE")
                guard let syntaxSelection else {
                    textSelection = []
                    return
                }
                textSelection = [syntaxSelection.range(in: document.text)]
            }
        }
        .onChange(of: textSelection) {
            update {
                print("TEXT SELECTION DID CHANGE")
                // TODO: This isn't triggering
                guard let syntax = document.compiled else {
                    return
                }
                let utf8 = document.text.utf8
                for textRange in textSelection {
                    let offset = utf8.distance(from: utf8.startIndex, to: textRange.lowerBound)
                    syntaxSelection = syntax.findDeepest(containingUTFIndex: offset)?.as(Syntax.self)
                }
            }
        }
    }

    func update(_ block: () -> Void) {
        guard allowUpdates == true else {
            return
        }
        allowUpdates = false
        defer {
            allowUpdates = true
        }
        block()
    }
}

#Preview {
    ContentView(document: .constant(SwiftExplorerDocument()))
}

struct SyntaxPathView: View {
    @Binding
    var syntax: Syntax

    var syntaxes: [Syntax] {
        return syntax.ancestors.map { $0.as(Syntax.self)! } + [syntax]
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(syntaxes) { syntax in
                    if syntax.id != syntaxes.first?.id {
                        Image(systemName: "arrowtriangle.forward.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        //                    .opacity(0.5)
                    }
                    Button {
                        self.syntax = syntax
                    } label: {
                        Text(syntax.typeName)
                    }
                    .buttonStyle(.borderless)
                    .fixedSize()
                }
            }
            .fixedSize(horizontal: true, vertical: true)
        }
        .scrollIndicators(.hidden)
    }
}

struct SyntaxView: View {
    let syntax: Syntax

    @Binding
    var selection: Boxed<Syntax>.ID?

    init(syntax: Syntax, selection: Binding<Syntax?> ) {
        self.syntax = syntax
        self._selection = Binding<Boxed<Syntax>.ID?> {
            return selection.wrappedValue.map { Boxed<Syntax>.ID(rawValue: $0) }
        } set: { newValue in
            selection.wrappedValue = newValue?.rawValue
        }
    }

    var body: some View {
        VSplitView {
            let root = Boxed(syntax)
            Table([root], children: \.children, selection: $selection) {
                TableColumn("Type", value: \.rawValue.typeName)
            }
            .alternatingRowBackgrounds(.disabled)
            .tableColumnHeaders(.hidden)
            detailView
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    var detailView: some View {
        if let value = selection?.rawValue {
            Form {
                LabeledContent("type") { Text(value.typeName) }
                LabeledContent("position") { Text(describing: value.position.utf8Offset) }
                LabeledContent("length") { Text(describing: value.contentLength.utf8Length) }
                LabeledContent("leading trivia") { Text(describing: value.leadingTrivia) }
                LabeledContent("trailing trivia") { Text(describing: value.trailingTrivia) }
            }
            .padding()
        }
    }
}

struct SourceView: View {
    @Binding
    var source: String

    @Binding
    var selection: [Range<String.Index>]

    // Still using ObservableObject here due to a bug with lifetime of Observed objects.
    class Model: NSObject, ObservableObject, NSTextViewDelegate {

        var textDidChange: ((String) -> Void)? = nil
        var selectionDidChange: (([Range<String.Index>]) -> Void)? = nil

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else {
                fatalError()
            }
            guard let text = view.textStorage?.string else {
                return
            }
            textDidChange?(text)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else {
                fatalError()
            }
            guard let text = view.textStorage?.string else {
                return
            }
            let ranges = view.selectedRanges
                .map { $0.value(of: NSRange.self)! }
                .map { Range($0, in: text)! }
            selectionDidChange?(ranges)
        }
    }

    @StateObject
    var model = Model()

    var body: some View {
        ViewAdaptor<NSTextView> {
            let view = NSTextView()
            view.delegate = model
            model.textDidChange = {
                source = $0
            }
            model.selectionDidChange = {
                selection = $0
            }
            return view
        } update: { view in
            if source != view.textStorage?.string {
                view.textStorage?.mutableString.setString(source)
                view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            }
            if selection.isEmpty {
                view.selectedRanges = [NSValue(range: NSRange(location: 0, length: 0))]
            }
            else {
                view.selectedRanges = selection.map {
                    NSValue(range: NSRange($0, in: source))
                }
            }
        }
    }
}

extension SyntaxProtocol {
    @discardableResult
    func walk(_ visitor: (SyntaxProtocol) -> Bool) -> Bool {
        if visitor(self) == false {
            return false
        }
        for child in children(viewMode: .all) {
            if child.walk(visitor) == false {
                return false
            }
        }
        return true
    }

    func findDeepest(containingUTFIndex index: Int) -> SyntaxProtocol? {
        guard utf8Range.contains(index) else {
            return nil
        }
        let children = children(viewMode: .all).filter {
            return $0.utf8Range.contains(index)
        }
        assert(children.count <= 1)
        
        if children.isEmpty {
            return self
        }
        else {
            return children[0].findDeepest(containingUTFIndex: index)
        }
    }
}

extension SyntaxProtocol {
    var utf8Range: Range<Int> {
        position.utf8Offset ..< (position.utf8Offset + totalLength.utf8Length)
    }

}

extension Syntax {
    var syntaxEnum: SyntaxEnum.Meta {
        return SyntaxEnum.Meta(self.as(SyntaxEnum.self))
    }
    var typeName: String {
        return String(describing: syntaxEnum)
    }
}

extension Boxed where Raw == Syntax {
    var children: [Self]? {
        let children = rawValue.children(viewMode: .all).map({ Boxed($0) })
        if children.isEmpty {
            return nil
        }
        return children
    }
}

extension SyntaxProtocol {

    // TODO: trivia optional?
    func range(in string: String) -> Range<String.Index> {
        let utf8 = string.utf8
        let start = utf8.index(utf8.startIndex, offsetBy: positionAfterSkippingLeadingTrivia.utf8Offset)
        let end = utf8.index(start, offsetBy: contentLength.utf8Length)
        return start..<end
    }
}
