//
//  CameraPicker.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/5/26.
//

import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UIImagePickerController` configured for taking photos with the camera.
struct CameraPicker: UIViewControllerRepresentable {
    /// Callback invoked when an image is picked
    let onImagePicked: (UIImage) -> Void
    
    /// Environment dismiss action to close the sheet
    @Environment(\.dismiss) private var dismiss

    //  UIViewControllerRepresentable

    /// Create and configure the `UIImagePickerController`
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera // Use camera as source
        picker.delegate = context.coordinator // Set delegate to handle callbacks
        return picker
    }

    /// Required by protocol, updates the view controller (unused here)
    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    /// Create the Coordinator to handle delegate callbacks
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator

    /// Coordinator acts as delegate for `UIImagePickerController`
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        /// Called when the user picks an image
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            // Retrieve the original image
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image) // Pass it back via the callback
            }
            parent.dismiss() // Close the picker
        }

        /// Called when the user cancels the picker
        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {
            parent.dismiss() // Close the picker
        }
    }
}
