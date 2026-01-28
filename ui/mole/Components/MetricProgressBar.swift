//
//  MetricProgressBar.swift
//  mole
//

import SwiftUI

struct MetricProgressBar: View {
    let value: Double // 0.0–1.0
    let label: String

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var barColor: Color {
        if clampedValue < 0.5 { return Color(red: 0.30, green: 0.75, blue: 0.35) }
        if clampedValue < 0.8 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))

                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(clampedValue))
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(clampedValue * 100)) percent")
    }
}

#Preview {
    VStack(spacing: 12) {
        MetricProgressBar(value: 0.3, label: "Low usage")
        MetricProgressBar(value: 0.58, label: "Medium usage")
        MetricProgressBar(value: 0.67, label: "High usage")
        MetricProgressBar(value: 0.85, label: "Critical usage")
    }
    .padding()
    .preferredColorScheme(.dark)
}
