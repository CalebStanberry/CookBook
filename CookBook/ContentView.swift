//
//  ContentView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/20/25.
//

import SwiftUI
import SwiftData
import LinkPresentation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showAddLinkSheet = false
    @State private var urlText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        Link(destination: URL(string: item.url)!) {
                            CardView(item: item)
                        }
                        .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("CookBook")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddLinkSheet = true
                    } label: {
                        Label("Add Recipe", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddLinkSheet) {
            NavigationStack {
                Form {
                    Section("Recipe Link") {
                        TextField("https://example.com", text: $urlText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("Add Recipe")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addLink()
                        }
                        .disabled(URL(string: urlText) == nil)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            urlText = ""
                            showAddLinkSheet = false
                        }
                    }
                }
            }
        }
    }

    private func addLink() {
        guard let url = URL(string: urlText) else { return }

        let item = Item(url: url.absoluteString)
        modelContext.insert(item)

        showAddLinkSheet = false
        urlText = ""

        fetchPreview(for: item, url: url)
    }
    
    private func delete(_ item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }
    
    // Derive site name from url
    private func siteName(from url: URL) -> String {
        url.host?
            .replacingOccurrences(of: "www.", with: "")
            .capitalized ?? ""
    }
    
    private func fetchPreview(for item: Item, url: URL) {
        let provider = LPMetadataProvider()

        provider.startFetchingMetadata(for: url) { metadata, error in
            guard let metadata else { return }

            DispatchQueue.main.async {
                item.title = metadata.title
                item.siteName = siteName(from: url)
            }

            if let imageProvider = metadata.imageProvider {
                imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    guard let image = image as? UIImage else { return }
                    if let path = saveImage(image) {
                        DispatchQueue.main.async {
                            item.imagePath = path
                        }
                    }
                }
            }

            if let iconProvider = metadata.iconProvider {
                iconProvider.loadObject(ofClass: UIImage.self) { icon, _ in
                    guard let icon = icon as? UIImage else { return }
                    if let path = saveImage(icon) {
                        DispatchQueue.main.async {
                            item.iconPath = path
                        }
                    }
                }
            }
        }
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(UUID().uuidString + ".jpg")

        try? data.write(to: url)
        return url.path
    }
}


struct CardView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let path = item.imagePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            }

            HStack(spacing: 8) {
                if let iconPath = item.iconPath,
                   let icon = UIImage(contentsOfFile: iconPath) {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }

                Text(item.siteName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.title ?? "Loading preview…")
                .font(.headline)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
