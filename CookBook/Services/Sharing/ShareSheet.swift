//
//  ShareSheet.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/5/26.
//
//  A SwiftUI wrapper for UIKit's UIActivityViewController, allowing sharing of
//  arbitrary items (text, URLs, images, etc.) from a SwiftUI view.
//
//  Notes:
//  - Use in a `.sheet` modifier to present share options.
//  - Handles popover presentation for iPad automatically.
//  - Items array can contain any type supported by UIActivityViewController.
//

import SwiftUI

/// SwiftUI wrapper around `UIActivityViewController`.
/// Enables sharing content from SwiftUI views.
struct ShareSheet: UIViewControllerRepresentable {

    /// Items to share (String, URL, UIImage, etc.)
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Initialize UIKit share sheet with activity items
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Handle iPad popover to avoid runtime crash
        if let popover = activityVC.popoverPresentationController {
            // Use the key window's root view as the source
            if let window = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first(where: \.isKeyWindow) {

                popover.sourceView = window
                popover.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No dynamic updates needed
    }
}
