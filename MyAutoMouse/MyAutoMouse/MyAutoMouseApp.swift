//
//  MyAutoMouseApp.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import SwiftUI

@main
struct MyAutoMouseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 450)
        }
        .windowResizability(.contentSize)
    }
}
