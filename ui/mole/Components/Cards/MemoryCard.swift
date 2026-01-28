//
//  MemoryCard.swift
//  mole
//

import SwiftUI

struct MemoryCard: View {
    let usagePercent: Double
    let usedGB: Int
    let totalGB: Int

    var body: some View {
        MetricCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Memory")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "memorychip")
                        .foregroundStyle(.pink)
                }

                Text("\(Int(usagePercent * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                MetricProgressBar(value: usagePercent, label: "Memory usage")

                Text("\(usedGB) / \(totalGB) GB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MemoryCard(usagePercent: 0.58, usedGB: 14, totalGB: 24)
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.dark)
}
