//
//  SwiftExplorerApp.swift
//  SwiftExplorer
//
//  Created by Jonathan Wight on 6/12/23.
//

import SwiftUI

@main
struct SwiftExplorerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SwiftExplorerDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
