//
//  SidebarSection.swift
//  mole
//

import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard
    case clean
    case uninstall
    case analyze
    case optimize
    case status
    case purge
    case installers
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .clean: return "Clean"
        case .uninstall: return "Uninstall"
        case .analyze: return "Analyze"
        case .optimize: return "Optimize"
        case .status: return "Status"
        case .purge: return "Purge"
        case .installers: return "Installers"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "bolt.fill"
        case .clean: return "paintbrush.fill"
        case .uninstall: return "trash.fill"
        case .analyze: return "circle.fill"
        case .optimize: return "wrench.and.screwdriver.fill"
        case .status: return "chart.bar.fill"
        case .purge: return "folder.fill"
        case .installers: return "archivebox.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return .green
        case .clean: return .yellow
        case .uninstall: return .gray
        case .analyze: return .orange
        case .optimize: return .gray
        case .status: return .green
        case .purge: return .blue
        case .installers: return .orange
        case .settings: return .gray
        }
    }

    static var mainSections: [SidebarSection] {
        [.dashboard, .clean, .uninstall, .analyze, .optimize]
    }

    static var toolsSections: [SidebarSection] {
        [.status]
    }

    static var utilitySections: [SidebarSection] {
        [.purge, .installers]
    }

    static var settingsSections: [SidebarSection] {
        [.settings]
    }

    static var groupedSections: [[SidebarSection]] {
        [mainSections, toolsSections, utilitySections, settingsSections]
    }
}
