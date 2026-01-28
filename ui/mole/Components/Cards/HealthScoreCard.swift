//
//  HealthScoreCard.swift
//  mole
//

import SwiftUI

struct HealthScoreCard: View {
    let score: Int
    let status: String
    let message: String

    var body: some View {
        MetricCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Health Score")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "heart")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    HealthScoreRing(score: score)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status)
                            .font(.title3.bold())

                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HealthScoreCard(score: 92, status: "Excellent", message: "System healthy")
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.dark)
}
