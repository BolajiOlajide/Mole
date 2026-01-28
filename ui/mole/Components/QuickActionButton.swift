//
//  QuickActionButton.swift
//  mole
//

import SwiftUI

struct QuickActionButton: View {
    let label: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Navigates to \(label)")
    }
}

#Preview {
    HStack(spacing: 12) {
        QuickActionButton(label: "Clean", icon: "paintbrush.fill", iconColor: .yellow) {}
        QuickActionButton(label: "Optimize", icon: "wrench.and.screwdriver.fill", iconColor: .gray) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}
