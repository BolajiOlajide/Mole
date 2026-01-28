//
//  DiskUsageCard.swift
//  mole
//

import SwiftUI

struct DiskUsageCard: View {
    let usagePercent: Double
    let freeGB: Int

    var body: some View {
        MetricCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Disk Usage")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(usagePercent * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                MetricProgressBar(value: usagePercent, label: "Disk usage")

                Text("\(freeGB) GB free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DiskUsageCard(usagePercent: 0.67, freeGB: 156)
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.dark)
}
