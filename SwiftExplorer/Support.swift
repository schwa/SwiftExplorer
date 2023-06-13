import SwiftUI

extension Text {
    init(describing value: Any) {
        self = Text(String(describing: value))
    }
}

struct Boxed <Raw>: Identifiable where Raw: Identifiable {
    let rawValue: Raw

    init(_ rawValue: Raw) {
        self.rawValue = rawValue
    }

    var id: ID {
        return ID(rawValue: rawValue)
    }

    struct ID: Hashable {
        static func == (lhs: Boxed<Raw>.ID, rhs: Boxed<Raw>.ID) -> Bool {
            lhs.rawValue.id == rhs.rawValue.id
        }

        func hash(into hasher: inout Hasher) {
            rawValue.id.hash(into: &hasher)
        }

        let rawValue: Raw
    }

}
