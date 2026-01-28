//
//  CacheSizeCard.swift
//  mole
//

import SwiftUI

struct CacheSizeCard: View {
    let sizeGB: Double
    let status: String
    let lastCleaned: String

    var body: some View {
        MetricCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cache Size")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                }

                Text(String(format: "%.1f GB", sizeGB))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.green)

                Text("Last cleaned: \(lastCleaned)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CacheSizeCard(sizeGB: 8.4, status: "Ready to clean", lastCleaned: "3d ago")
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.dark)
}
