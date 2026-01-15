//
//  EditRecipeView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/14/26.
//

import SwiftUI
import PhotosUI
import SwiftData

// Edit Recipe View

/// Allows editing a recipe including title, hero image, ingredients, and steps.
struct EditRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var recipe: Recipe
    @Binding var showAddRecipe: Bool

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Hero Image + Actions
                heroSection

                VStack{
                    // Recipe Title
                    Text("Recipe Name")
                        .font(.subheadline)
                    Spacer(minLength: 14)
                    TextField("Enter the recipe title", text: $recipe.title)
                        .textFieldStyle(.roundedBorder)
                    Spacer(minLength: 32)

                    // Ingredients
                    editIngredientsSection
                    Spacer(minLength: 32)

                    // Steps
                    editStepsSection
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showAddRecipe = false
                dismiss()
            } label: {
                Text("Done")
            }
        }
        // PhotosPicker integration
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }

            Task {
                // Load selected image data and save
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveHeroImage(image)
                }
            }
        }
        // Camera integration
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                saveHeroImage(image)
            }
        }
        .onDisappear() {
            // Save any changes when leaving edit view
            recipe.pushIfShared()
        }
    }

    // Hero Section with Camera / Photo options
    private var heroSection: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                Group {
                    if let path = recipe.heroImageFullPath,
                       let image = UIImage(contentsOfFile: path) {

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 220)
                            .clipped()

                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: geo.size.width, height: 220)
                    }
                }

                HStack {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take a photo", systemImage: "camera")
                    }

                    Spacer()

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Upload a photo", systemImage: "photo")
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(height: 220 + 44) // Image + buttons
    }

    // Edit Ingredients Section
    private var editIngredientsSection: some View {
        VStack {
            HStack{
                Text("Ingredients")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
            }
            .overlay(alignment: .trailing) {
                Button { addIngredient() } label: {
                    Image(systemName: "plus")
                }
                .padding(.trailing)
            }

            Spacer(minLength: 14)

            ForEach($recipe.ingredients) { $ingredient in
                HStack {
                    TextField("Enter the ingredient", text: $ingredient.name)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                    TextField("Enter the amount", text: $ingredient.amount)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .onDelete { indices in
                recipe.ingredients.remove(atOffsets: indices)
            }
            .onMove { indices, newOffset in
                recipe.ingredients.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
    }

    // Edit Steps Section
    private var editStepsSection: some View {
        VStack {
            HStack{
                Text("Steps")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.subheadline)
            }
            .overlay(alignment: .trailing) {
                Button { recipe.steps.append("New Step") } label: {
                    Image(systemName: "plus")
                }
                .padding(.trailing)
            }

            Spacer(minLength: 14)

            ForEach($recipe.steps.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1). ")
                    TextEditor(text: $recipe.steps[index])
                        .textFieldStyle(.roundedBorder)
                }
            }
            .onDelete { indices in
                recipe.steps.remove(atOffsets: indices)
            }
            .onMove { indices, newOffset in
                recipe.steps.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
    }

    // Add a new ingredient
    private func addIngredient() {
        let newIngredient = Ingredient(name: "New Ingredient", amount: "")
        newIngredient.recipe = recipe
        recipe.ingredients.append(newIngredient)
        modelContext.insert(newIngredient)
    }

    // Add a new step
    private func addStep() {
        let newStep = "New Step"
        recipe.steps.append(newStep)
        try? modelContext.save()
    }

    // Save hero image to local storage and update recipe
    @MainActor
    private func saveHeroImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }

        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        try? data.write(to: url)

        recipe.heroImageFileName = savePath(url.path) // Update recipe with file path
        recipe.needsImageUpload = true
        try? modelContext.save()
    }
}
