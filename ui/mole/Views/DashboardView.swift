//
//  DashboardView.swift
//  mole
//

import SwiftUI

struct DashboardView: View {
    let metrics: DashboardMetrics
    var onNavigate: ((SidebarSection) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard")
                    .font(.title.bold())

                // Metric cards — 2x2 grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    HealthScoreCard(
                        score: metrics.healthScore,
                        status: metrics.healthStatus,
                        message: metrics.healthMessage
                    )

                    DiskUsageCard(
                        usagePercent: metrics.diskUsagePercent,
                        freeGB: metrics.diskFreeGB
                    )

                    MemoryCard(
                        usagePercent: metrics.memoryUsagePercent,
                        usedGB: metrics.memoryUsedGB,
                        totalGB: metrics.memoryTotalGB
                    )

                    CacheSizeCard(
                        sizeGB: metrics.cacheSize,
                        status: metrics.cacheStatus,
                        lastCleaned: metrics.lastCleaned
                    )
                }

                // Quick Actions
                HStack(spacing: 12) {
                    QuickActionButton(
                        label: "Clean",
                        icon: "paintbrush.fill",
                        iconColor: .yellow
                    ) {
                        onNavigate?(.clean)
                    }
                    QuickActionButton(
                        label: "Optimize",
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: .gray
                    ) {
                        onNavigate?(.optimize)
                    }
                    QuickActionButton(
                        label: "Status",
                        icon: "chart.bar.fill",
                        iconColor: .green
                    ) {
                        onNavigate?(.status)
                    }
                    QuickActionButton(
                        label: "Purge",
                        icon: "folder.fill",
                        iconColor: .gray
                    ) {
                        onNavigate?(.purge)
                    }
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    DashboardView(metrics: .mock) { section in
        print("Navigate to \(section.title)")
    }
    .frame(width: 700, height: 500)
    .preferredColorScheme(.dark)
}
