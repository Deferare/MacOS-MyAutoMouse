//
//  ContentView.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: AppSection = .click

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            NavigationStack {
                selectedSectionView
                    .navigationTitle(selection.title)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch selection {
        case .click:
            ClickView()
        case .about:
            AboutView()
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case click
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .click:
            return "Click"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .click:
            return "cursorarrow.click"
        case .about:
            return "info.circle"
        }
    }
}

#Preview {
    ContentView()
}
