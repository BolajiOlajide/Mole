//
//  ContentView.swift
//  mole
//
//  Created by Bolaji Olajide on 28/01/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSection: SidebarSection = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            detailView
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(metrics: .mock) { section in
                selectedSection = section
            }
        default:
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedSection.icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(selectedSection.title)
                .font(.title2.bold())
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1040, height: 680)
        .preferredColorScheme(.dark)
}
