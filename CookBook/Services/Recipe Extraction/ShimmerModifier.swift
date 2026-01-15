//
//  ShimmerModifier.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/28/25.
//
//  Adds a shimmering effect to a view, often used for loading placeholders.
//

import SwiftUI

/// A ViewModifier that applies a shimmer animation overlay
struct ShimmerModifier: ViewModifier {
    
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            // Overlay a moving gradient
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)  // Gradient covers half width
                    .offset(x: geometry.size.width * phase - geometry.size.width * 0.5)
                }
            )
            .onAppear {
                // Animate phase continuously
                withAnimation(
                    .linear(duration: 1.7)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.3
                }
            }
    }
}

// View Extension for Easy Usage

extension View {
    
    /// Applies a shimmer effect if `active` is true
    /// - Parameter active: Whether the shimmer effect should be active
    /// - Returns: The original view with shimmer overlay applied if active
    @ViewBuilder
    func shimmer(_ active: Bool) -> some View {
        if active {
            self.modifier(ShimmerModifier())
        } else {
            self
        }
    }
}
