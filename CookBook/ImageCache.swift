//
//  ImageCache.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//


func saveImage(_ image: UIImage) -> String? {
    let url = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(UUID().uuidString + ".jpg")

    guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    try? data.write(to: url)
    return url.path
}