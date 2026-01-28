//
//  SidebarView.swift
//  mole
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarSection.mainSections) { section in
                    sidebarRow(section)
                }
            }

            Section {
                ForEach(SidebarSection.toolsSections) { section in
                    sidebarRow(section)
                }
            }

            Section {
                ForEach(SidebarSection.utilitySections) { section in
                    sidebarRow(section)
                }
            }

            Section {
                ForEach(SidebarSection.settingsSections) { section in
                    sidebarRow(section)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ section: SidebarSection) -> some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(section.color)
        }
        .tag(section)
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
