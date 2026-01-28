//
//  HealthScoreRing.swift
//  mole
//

import SwiftUI

struct HealthScoreRing: View {
    let score: Int
    let lineWidth: CGFloat = 8

    private var progress: Double {
        Double(min(max(score, 0), 100)) / 100.0
    }

    private var ringColor: Color {
        if score >= 90 { return Color(red: 0.30, green: 0.75, blue: 0.35) }
        if score >= 75 { return Color(red: 0.55, green: 0.78, blue: 0.35) }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    ringColor.opacity(0.2),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health score: \(score) out of 100")
        .accessibilityValue("\(score) percent")
    }
}

#Preview {
    HealthScoreRing(score: 92)
        .frame(width: 80, height: 80)
        .padding()
        .preferredColorScheme(.dark)
}
