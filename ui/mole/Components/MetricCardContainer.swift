//
//  MetricCardContainer.swift
//  mole
//

import SwiftUI

struct MetricCardContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MetricCardContainer {
        Text("Sample card content")
    }
    .frame(width: 300)
    .padding()
    .preferredColorScheme(.dark)
}
